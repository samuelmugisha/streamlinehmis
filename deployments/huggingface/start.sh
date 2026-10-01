#!/bin/bash
# Boot sequence for the Hospilot HF Space: Postgres + Redis first, then supervisord
# (Hasura, mock-HIS, Fabric, backend, nginx); Hasura metadata is applied once
# Hasura is healthy, which unblocks the backend.
set -euo pipefail

PGDATA=/data/pg
PG_URL=postgresql://hospilot:hospilot@127.0.0.1:5432/hospilot

# ── secrets / config (set these as Space secrets & variables) ─────────────────
: "${LLM_API_KEY:?Set LLM_API_KEY as a Space secret}"
: "${BOOTSTRAP_ADMIN_PASSWORD:?Set BOOTSTRAP_ADMIN_PASSWORD as a Space secret}"
export LLM_API_KEY BOOTSTRAP_ADMIN_PASSWORD
export BOOTSTRAP_ADMIN_USERNAME="${BOOTSTRAP_ADMIN_USERNAME:-admin}"
export JWT_SECRET="${JWT_SECRET:-$(head -c 32 /dev/urandom | base64)}"
export LLM_PROVIDER="${LLM_PROVIDER:-openai}"
export LLM_BASE_URL="${LLM_BASE_URL:-https://openrouter.ai/api/v1}"
export LLM_MODEL="${LLM_MODEL:-anthropic/claude-sonnet-4}"
export LLM_FAST_MODEL="${LLM_FAST_MODEL:-anthropic/claude-haiku-4.5}"
export LLM_QUALITY_MODEL="${LLM_QUALITY_MODEL:-anthropic/claude-sonnet-4}"
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"

export HASURA_GRAPHQL_ADMIN_SECRET="$(head -c 24 /dev/urandom | base64 | tr -d '/+=')"
export HASURA_GRAPHQL_DATABASE_URL="$PG_URL"
export HASURA_GRAPHQL_SERVER_PORT=8080
export HASURA_GRAPHQL_SERVER_HOST=127.0.0.1
export HASURA_GRAPHQL_ENABLE_CONSOLE=false
export HASURA_URL=http://127.0.0.1:8080/v1/graphql
export HASURA_ADMIN_SECRET="$HASURA_GRAPHQL_ADMIN_SECRET"
export DATABASE_URL="$PG_URL"
export REDIS_URL=redis://127.0.0.1:6379
export FABRIC_BASE_URL=http://127.0.0.1:8001
export FABRIC_API_KEY=""
export KAFKA_ENABLED=false
export TEMPORAL_ENABLED=false
export SCHEDULER_ENABLED=true
export AUTONOMOUS_POLICY_ENABLED=false
export APP_ENV=production
export APP_BASE_URL="https://${SPACE_HOST:-localhost:7860}"
export CORS_ORIGINS="*"
export FLOW_LOG_DIR=/tmp/flow-logs

# ── Postgres ──────────────────────────────────────────────────────────────────
FRESH=0
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    mkdir -p "$PGDATA"
    initdb -D "$PGDATA" -U hospilot --auth=trust >/dev/null
    FRESH=1
fi
pg_ctl -D "$PGDATA" -l /tmp/postgres.log -w \
    -o "-c listen_addresses=127.0.0.1 -c unix_socket_directories=/tmp" start
if [ "$FRESH" = 1 ]; then
    createdb -h 127.0.0.1 -U hospilot hospilot
    psql -q -h 127.0.0.1 -U hospilot -d hospilot -v ON_ERROR_STOP=1 \
        -f /app/hf/seed/hospilot.sql >/dev/null
    echo "[start] database seeded"
fi
# Demo operational data (billing, appointments, lab, staffing, OT), dated relative to
# today -- refreshed every boot; mock-HIS serves the same rows to Fabric.
python /app/mock-his/demo_data.py --sql \
    | psql -q -h 127.0.0.1 -U hospilot -d hospilot -v ON_ERROR_STOP=1 >/dev/null
echo "[start] demo data loaded"

# ── Redis ─────────────────────────────────────────────────────────────────────
redis-server --bind 127.0.0.1 --port 6379 --daemonize yes --save "" --dir /tmp

# ── app processes ─────────────────────────────────────────────────────────────
rm -f /tmp/hasura-ready
/usr/bin/supervisord -c /app/hf/supervisord.conf &
SUPERVISOR_PID=$!

until curl -sf http://127.0.0.1:8080/healthz >/dev/null; do sleep 1; done
python - <<'EOF'
import json, os, urllib.request
meta = json.load(open("/app/hf/seed/hasura_metadata.json"))
req = urllib.request.Request(
    "http://127.0.0.1:8080/v1/metadata",
    data=json.dumps({"type": "replace_metadata", "args": meta}).encode(),
    headers={"x-hasura-admin-secret": os.environ["HASURA_GRAPHQL_ADMIN_SECRET"],
             "content-type": "application/json"},
)
print("[start] hasura metadata:", urllib.request.urlopen(req).read().decode())
EOF
(cd /app/agentic-framework && python scripts/seed_redis.py)
touch /tmp/hasura-ready

wait "$SUPERVISOR_PID"

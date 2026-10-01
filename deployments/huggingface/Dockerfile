# Hospilot all-in-one image for a Hugging Face Docker Space.
#
# Spaces run a single container, so the compose stack is collapsed into one image:
# nginx (:7860) -> web UI + backend (:8000), Fabric (:8001), mock-HIS (:9000),
# Hasura (:8080), Postgres (:5432), Redis (:6379). Kafka and Temporal are left out —
# both are optional (KAFKA_ENABLED / TEMPORAL_ENABLED=false).
#
# Build context is the staging dir assembled by deployments/huggingface/deploy.sh.

# ── web UI (static build) ────────────────────────────────────────────────────
FROM node:22-slim AS web
WORKDIR /web
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
RUN npm run build

# ── Hasura binary (runtime libs installed below) ───────────────────────────────────────────────────
FROM hasura/graphql-engine:v2.36.0 AS hasura

# ── runtime ──────────────────────────────────────────────────────────────────
FROM python:3.11-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
        postgresql-15 redis-server nginx supervisor libpq-dev gcc curl ca-certificates \
        libpcre3 libodbc2 libgmp10 libltdl7 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=hasura /usr/bin/graphql-engine /usr/local/bin/graphql-engine

COPY agentic-framework/requirements.txt /tmp/req-af.txt
COPY fabric/requirements.txt /tmp/req-fabric.txt
RUN pip install --no-cache-dir -r /tmp/req-af.txt -r /tmp/req-fabric.txt

# Spaces run the container as uid 1000
RUN useradd -m -u 1000 user
WORKDIR /app
COPY --chown=user agentic-framework/ /app/agentic-framework/
COPY --chown=user fabric/ /app/fabric/
COPY --chown=user mock-his/ /app/mock-his/
COPY --chown=user hf/ /app/hf/
COPY --chown=user --from=web /web/dist /app/web

RUN chmod +x /app/hf/start.sh \
    && mkdir -p /data && chown user:user /data

USER user
ENV PATH=/usr/lib/postgresql/15/bin:$PATH \
    PYTHONUNBUFFERED=1

EXPOSE 7860
CMD ["/app/hf/start.sh"]

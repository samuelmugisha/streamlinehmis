#!/bin/bash
# Assemble the HF Space build context (what gets uploaded to the Space repo) into $1.
# Never includes .env files, node_modules, logs or caches.
set -euo pipefail

OUT="${1:?usage: build-context.sh <output-dir>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HF="$ROOT/deployments/huggingface"

rm -rf "$OUT" && mkdir -p "$OUT/hf"
EXCLUDES=(--exclude '.env' --exclude '.env.*' --exclude 'node_modules' --exclude 'dist'
          --exclude '__pycache__' --exclude '*.pyc' --exclude 'logs' --exclude '*.log'
          --exclude '.pytest_cache' --exclude 'tests' --exclude '.DS_Store')

rsync -a "${EXCLUDES[@]}" "$ROOT/agentic-framework" "$ROOT/fabric" "$ROOT/mock-his" "$ROOT/web" "$OUT/"
cp "$HF/Dockerfile" "$HF/README.md" "$OUT/"
cp -r "$HF/start.sh" "$HF/nginx.conf" "$HF/supervisord.conf" "$HF/seed" "$OUT/hf/"

if find "$OUT" -name '.env' -o -name '.env.*' ! -name '.env.example' | grep -q .; then
    echo "refusing: .env file found in build context" >&2; exit 1
fi
echo "build context ready: $OUT ($(du -sh "$OUT" | cut -f1))"

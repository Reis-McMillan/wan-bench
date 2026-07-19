#!/usr/bin/env bash
#
# Configurable via environment variables (override with -e / compose env):
#   docker compose run --rm -e NUM_PROMPTS=50 -e MAX_CONCURRENCY=4 bench
#
set -uo pipefail

SERVER_HOST="${SERVER_HOST:-localhost}"   # compose: the server service name
SERVER_PORT="${SERVER_PORT:-30001}"
TASK="${TASK:-text-to-video}"             # NOTE: not "t2v" (invalid choice)
DATASET="${DATASET:-vbench}"              # vbench | random
NUM_PROMPTS="${NUM_PROMPTS:-20}"
MAX_CONCURRENCY="${MAX_CONCURRENCY:-1}"

echo "[run_bench] Benchmarking server at ${SERVER_HOST}:${SERVER_PORT}" \
     "(dataset=${DATASET}, prompts=${NUM_PROMPTS}, concurrency=${MAX_CONCURRENCY})"

exec python3 -m sglang.multimodal_gen.benchmarks.bench_serving \
    --host "$SERVER_HOST" \
    --port "$SERVER_PORT" \
    --task "$TASK" \
    --dataset "$DATASET" \
    --num-prompts "$NUM_PROMPTS" \
    --max-concurrency "$MAX_CONCURRENCY"

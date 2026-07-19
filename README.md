# wan-bench

Benchmark [`Wan-AI/Wan2.2-T2V-A14B-Diffusers`](https://huggingface.co/Wan-AI/Wan2.2-T2V-A14B-Diffusers)
(text-to-video) served by [SGLang diffusion](https://docs.sglang.io/docs/sglang-diffusion)
on an **AMD Instinct MI300X** (ROCm, `gfx942`).

Two independent pieces:

| Piece | What it is | Lifetime | File |
|-------|-----------|----------|------|
| **Server** | `sglang serve` HTTP server (OpenAI-compatible video API) | Runs continuously | `docker-compose.yaml` |
| **Bench client** | `bench_serving` — drives the server over HTTP and reports throughput/latency. **Does not launch a server.** | Runs once and exits | `Dockerfile` + `run_bench.sh` |

Bring the server up with Compose, then run the benchmark container against it
whenever you want — the client is a discrete, finite job, so it's launched by
hand rather than being a Compose service.

---

## Requirements

- Docker with the Compose plugin.
- An AMD Instinct MI300X (or MI325X) ROCm host exposing `/dev/kfd` and `/dev/dri`.
- The base image pulled locally: `lmsysorg/sglang:v0.5.15.post1-rocm720-mi30x`.
- ~72 GB free disk for model weights (downloaded once into the `hf-cache` volume).

---

## 1. Start the server

```bash
docker compose up -d          # starts the sglang server

# First boot downloads ~72GB of weights and warms up — this takes a while.
docker compose logs -f sglang
docker inspect -f '{{.State.Health.Status}}' wan-sglang   # wait for "healthy"
```

The server listens on `http://localhost:30001` (published to the host) and stays
up until `docker compose down`.

## 2. Build the benchmark client

```bash
docker build -t wan-bench .
```

## 3. Run a benchmark

The client needs GPU access (see notes) and must be able to reach the server.
The simplest way is host networking, so `localhost:30001` resolves to the
server's published port:

```bash
docker run --rm \
  --network host \
  --device=/dev/kfd --device=/dev/dri \
  --group-add render --group-add video \
  --security-opt seccomp=unconfined \
  --ipc=host \
  -e SERVER_HOST=localhost -e SERVER_PORT=30001 \
  -e NUM_PROMPTS=20 -e MAX_CONCURRENCY=1 \
  wan-bench
```

Results are printed to stdout. Re-run with different `-e` values to change the
benchmark scale — no rebuild needed.

> Alternatively, join the server's Compose network instead of using host
> networking and address it by service name:
> ```bash
> docker run --rm --network wan-bench_default \
>   --device=/dev/kfd --device=/dev/dri --group-add render --group-add video \
>   --security-opt seccomp=unconfined --ipc=host \
>   -e SERVER_HOST=wan-sglang -e SERVER_PORT=30001 \
>   wan-bench
> ```

## 4. Tear down

```bash
docker compose down          # stop the server (keeps the weights volume)
docker compose down -v       # also delete hf-cache (weights re-download next time)
```

---

## Configuration

`run_bench.sh` reads these environment variables (pass with `-e`):

| Variable | Default | Meaning |
|----------|---------|---------|
| `SERVER_HOST` | `localhost` | Server hostname to benchmark against. |
| `SERVER_PORT` | `30001` | Server port. |
| `TASK` | `text-to-video` | `bench_serving --task`. Must be a valid choice (`text-to-video`, `image-to-video`, `text-to-image`, ...). **Not** `t2v`. |
| `DATASET` | `vbench` | Prompt dataset: `vbench` or `random`. |
| `NUM_PROMPTS` | `20` | Number of prompts to benchmark. |
| `MAX_CONCURRENCY` | `1` | Max concurrent in-flight requests. |

Server model / GPU settings live in the `sglang` service `command:` in
`docker-compose.yaml` (`--model-path`, `--num-gpus`, `--port`).

---

## Running the server standalone (without Compose)

The server needs ROCm device access, which Compose grants via device flags. The
equivalent raw `docker run`:

```bash
docker run --rm --init \
  --device=/dev/kfd --device=/dev/dri \
  --group-add render --group-add video \
  --security-opt seccomp=unconfined --cap-add SYS_PTRACE \
  --ipc=host --shm-size 16g \
  -p 30001:30001 \
  -v wan-bench_hf-cache:/root/.cache/huggingface \
  lmsysorg/sglang:v0.5.15.post1-rocm720-mi30x \
  sglang serve --model-path Wan-AI/Wan2.2-T2V-A14B-Diffusers \
               --num-gpus 1 --host 0.0.0.0 --port 30001
```

---

## Notes & gotchas

- **`--init` / PID 1 matters.** SGLang's GPU worker calls
  `kill_itself_when_parent_died()`, which runs
  `if os.getppid() == 1: os.kill(os.getpid(), SIGKILL)`. If `sglang` is PID 1 in
  the container, the worker's real parent *is* PID 1, so it false-positives and
  kills itself on startup (`Rank 0 scheduler is dead. Exit code: -9`, then an
  `EOFError`). The Compose server uses `init: true` (tini as PID 1); the raw
  `docker run` above uses `--init`. It is **not** an out-of-memory or ROCm problem.
  (The benchmark client doesn't launch a server, so it isn't affected.)

- **The client needs a GPU too.** `bench_serving` imports
  `sglang.multimodal_gen`, whose import chain touches `torch.cuda`, so the
  benchmark container must be given `/dev/kfd` / `/dev/dri` even though it only
  sends HTTP requests. It shares the server's GPU; its GPU usage is negligible.

- **Weights are cached, not baked in.** The `hf-cache` named volume holds the
  ~72 GB of weights so they download once and persist across restarts.

- **First startup is slow.** Weight download + load + warmup happens before
  `/health` reports ready; the healthcheck allows a 30-minute `start_period`.

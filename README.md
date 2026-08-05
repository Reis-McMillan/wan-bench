# wan-bench

Benchmark [`Wan-AI/Wan2.2-T2V-A14B-Diffusers`](https://huggingface.co/Wan-AI/Wan2.2-T2V-A14B-Diffusers)
(text-to-video) served by [SGLang diffusion](https://docs.sglang.io/docs/sglang-diffusion)
on an **AMD Instinct MI300X** and a **Nvidia H200**.

Depending on the card, the set up is different.

## MI 300x

Simple server setup:
```
docker compose -f docker-compose.yaml -f docker-compose.rocm.yaml
```

In order to run the benchmark:
```
docker build -t wan-bench .
docker run --rm \
  --network host \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add render \
  --group-add video \
  --security-opt seccomp=unconfined \
  --ipc=host \
  -e SERVER_HOST=localhost \
  -e SERVER_PORT=30001 \
  -e NUM_PROMPTS=1 \
  -e MAX_CONCURRENCY=1 \
  -e HEIGHT=720 \
  -e WIDTH=1280 \
  -e NUM_FRAMES=81 \
  wan-bench
```

I recommend taking a look at `run_bench.sh` if you would like to mess around with configurable parameters.

## Nvidia H200

This particular benchmark was run inside a RunPod container, as such it was not run in the same containerized fashion that the MI300x benchmark was.
Please note that `docker-compose.nvidia.yaml` was not used for the benchmark at all, but was added merely to provide symmetry to the MI300x benchmark,
in the case that the Nvidia benchmark should ever be run outside of a containerized environment.

### Setup
Update your `.bashrc` with the following environment variables:
```

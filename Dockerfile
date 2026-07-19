# Benchmark image: bundles run_bench.sh on top of the SGLang ROCm image.
# run_bench.sh launches the server internally, runs bench_serving against it,
# and prints the results, so the whole benchmark is a single `docker run`.
FROM lmsysorg/sglang:v0.5.15.post1-rocm720-mi30x

# Persist HF downloads here; mount a volume at this path at runtime so the
# ~72GB of weights are downloaded once and reused across runs.
ENV HF_HOME=/root/.cache/huggingface

WORKDIR /sgl-workspace

COPY run_bench.sh /run_bench.sh
RUN chmod +x /run_bench.sh

# The script is PID 1; it launches `sglang` as a child (see note in the script
# about the PID-1 self-kill in SGLang's GPU worker).
ENTRYPOINT ["/run_bench.sh"]

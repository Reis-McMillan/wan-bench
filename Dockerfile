ARG BACKEND=nvidia

FROM lmsysorg/sglang:dev AS base-nvidia
FROM lmsysorg/sglang:v0.5.15.post1-rocm720-mi30x AS base-rocm

FROM base-${BACKEND} AS final

ENV HF_HOME=/root/.cache/huggingface

WORKDIR /sgl-workspace

COPY run_bench.sh /run_bench.sh
RUN chmod +x /run_bench.sh

ENTRYPOINT ["/run_bench.sh"]

# https://github.com/actions/runner

# renovate: datasource=github-releases depName=actions/runner
ARG ACTIONS_RUNNER_VERSION=v2.336.0
# renovate: datasource=github-releases depName=actions/runner extractVersion=^v(?<version>.+)$
ARG ACTIONS_RUNNER_PKG_VERSION=2.336.0
ARG ACTIONS_RUNNER_ARCH=x64
ARG ACTIONS_RUNNER_SHA256=04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d

# renovate: datasource=github-releases depName=aquaproj/aqua
ARG AQUA_VERSION=v2.62.3
# renovate: datasource=github-releases depName=aquaproj/aqua-registry
ARG AQUA_REGISTRY_VERSION=v4.550.0

FROM debian:13.6-slim@sha256:3a39a0592364683e6bab97937b72cad5a8fa6dcbbee90edb3bb48c7f8e94f258 AS runner-source
ARG ACTIONS_RUNNER_VERSION
ARG ACTIONS_RUNNER_PKG_VERSION
ARG ACTIONS_RUNNER_ARCH
ARG ACTIONS_RUNNER_SHA256

ADD --checksum=sha256:${ACTIONS_RUNNER_SHA256} \
    https://github.com/actions/runner/releases/download/${ACTIONS_RUNNER_VERSION}/actions-runner-linux-${ACTIONS_RUNNER_ARCH}-${ACTIONS_RUNNER_PKG_VERSION}.tar.gz \
    /tmp/runner.tar.gz
RUN mkdir /opt/runner && tar -xz -f /tmp/runner.tar.gz -C /opt/runner

FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS aqua-cli
ARG AQUA_VERSION
ARG AQUA_SHA256
ARG TARGETARCH

ADD --checksum=sha256:${AQUA_SHA256} --unpack=true \
    https://github.com/aquaproj/aqua/releases/download/${AQUA_VERSION}/aqua_linux_${TARGETARCH}.tar.gz \
    /tmp/
RUN install --mode=0755 /tmp/aqua /usr/local/bin/aqua

FROM debian:13.6-slim@sha256:3a39a0592364683e6bab97937b72cad5a8fa6dcbbee90edb3bb48c7f8e94f258

ARG AQUA_REGISTRY_VERSION
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    libicu76 \
    liblttng-ust1 \
    libssl3 \
    make \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL -o /etc/apt/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

COPY --from=docker:29.7.1-cli@sha256:27a51d5ab1cd38d9eeaba7b415b8c07bc10c31e1cf1ec8d78f6413fcfab3f44f /usr/local/bin/docker /usr/local/bin/docker
COPY --from=moby/buildkit:v0.32.2@sha256:28a898719c18a33f4e8000685287fa36fd0dd9560c6440227d3a732d79bb41d8 /usr/bin/buildctl /usr/local/bin/buildctl
COPY --from=mikefarah/yq:4.53.3@sha256:11a1f0b604b13dbbdc662260d8db6f644b22d8553122a25c1b5b2e8713ca6977 /usr/bin/yq /usr/local/bin/yq

COPY --from=aqua-cli /usr/local/bin/aqua /usr/local/bin/aqua
ADD --chown=1001:1001 https://github.com/aquaproj/aqua-registry.git#${AQUA_REGISTRY_VERSION} /opt/aqua-registry

RUN groupadd --gid 1001 runner \
    && useradd --uid 1001 --gid 1001 --create-home --shell /bin/bash runner \
    && mkdir --parents /home/runner/.local/share/aquaproj-aqua \
    && chown --recursive 1001:1001 /home/runner

COPY --from=runner-source --chown=1001:1001 /opt/runner /home/runner/actions-runner

USER 1001
WORKDIR /home/runner/actions-runner

ENV AQUA_ROOT_DIR=/home/runner/.local/share/aquaproj-aqua \
    AQUA_GLOBAL_CONFIG=/opt/aqua-registry/aqua-all.yaml \
    AQUA_DISABLE_POLICY=true \
    PATH=/usr/local/bin:/usr/bin:/bin:/home/runner/.local/share/aquaproj-aqua/bin

RUN aqua install --only-link --all

ENTRYPOINT ["./run.sh"]

# https://github.com/actions/runner

# renovate: datasource=github-releases depName=actions/runner
ARG ACTIONS_RUNNER_VERSION=v2.335.1
# renovate: datasource=github-releases depName=actions/runner extractVersion=^v(?<version>.+)$
ARG ACTIONS_RUNNER_PKG_VERSION=2.335.1
ARG ACTIONS_RUNNER_ARCH=x64
ARG ACTIONS_RUNNER_SHA256=4ef2f25285f0ae4477f1fe1e346db76d2f3ebf03824e2ddd1973a2819bf6c8cf

FROM debian:13.5-slim@sha256:28de0877c2189802884ccd20f15ee41c203573bd87bb6b883f5f46362d24c5c2 AS runner-source
ARG ACTIONS_RUNNER_VERSION
ARG ACTIONS_RUNNER_PKG_VERSION
ARG ACTIONS_RUNNER_ARCH
ARG ACTIONS_RUNNER_SHA256

ADD --checksum=sha256:${ACTIONS_RUNNER_SHA256} \
    https://github.com/actions/runner/releases/download/${ACTIONS_RUNNER_VERSION}/actions-runner-linux-${ACTIONS_RUNNER_ARCH}-${ACTIONS_RUNNER_PKG_VERSION}.tar.gz \
    /tmp/runner.tar.gz
RUN mkdir /opt/runner && tar -xz -f /tmp/runner.tar.gz -C /opt/runner

FROM debian:13.5-slim@sha256:28de0877c2189802884ccd20f15ee41c203573bd87bb6b883f5f46362d24c5c2

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

COPY --from=docker:29.6.0-cli@sha256:d14410ab6f87a2b6c14b7150de787cd7b8bb012a8e900966d6d893e9f7fc49b6 /usr/local/bin/docker /usr/local/bin/docker
COPY --from=moby/buildkit:v0.31.1@sha256:6b59b7df63a8cb9902736f9ddf7fcff8261613d3e7449b8ea8b7537fc399c03a /usr/bin/buildctl /usr/local/bin/buildctl
COPY --from=mikefarah/yq:4.53.3@sha256:11a1f0b604b13dbbdc662260d8db6f644b22d8553122a25c1b5b2e8713ca6977 /usr/bin/yq /usr/local/bin/yq

RUN groupadd --gid 1001 runner \
    && useradd --uid 1001 --gid 1001 --create-home --shell /bin/bash runner

COPY --from=runner-source --chown=runner:runner /opt/runner /home/runner/actions-runner

USER runner
WORKDIR /home/runner/actions-runner

ENTRYPOINT ["./run.sh"]

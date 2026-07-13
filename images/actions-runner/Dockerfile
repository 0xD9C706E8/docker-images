# https://github.com/actions/runner

# renovate: datasource=github-releases depName=actions/runner
ARG ACTIONS_RUNNER_VERSION=v2.335.1
# renovate: datasource=github-releases depName=actions/runner extractVersion=^v(?<version>.+)$
ARG ACTIONS_RUNNER_PKG_VERSION=2.335.1
ARG ACTIONS_RUNNER_ARCH=x64
ARG ACTIONS_RUNNER_SHA256=4ef2f25285f0ae4477f1fe1e346db76d2f3ebf03824e2ddd1973a2819bf6c8cf

# renovate: datasource=github-releases depName=aquaproj/aqua
ARG AQUA_VERSION=v2.60.2
# renovate: datasource=github-releases depName=aquaproj/aqua-registry
ARG AQUA_REGISTRY_VERSION=v4.536.1

FROM debian:13.5-slim@sha256:28de0877c2189802884ccd20f15ee41c203573bd87bb6b883f5f46362d24c5c2 AS runner-source
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
ARG TARGETARCH

RUN apk add --no-cache curl tar \
 && case "${TARGETARCH}" in \
        amd64) AQUA_ARCH=amd64 ;; \
        arm64) AQUA_ARCH=arm64 ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac \
 && curl --silent --location --fail \
        --output /tmp/aqua.tar.gz \
        "https://github.com/aquaproj/aqua/releases/download/${AQUA_VERSION}/aqua_linux_${AQUA_ARCH}.tar.gz" \
 && tar --extract --gzip --file=/tmp/aqua.tar.gz --directory=/tmp aqua \
 && install --mode=0755 /tmp/aqua /usr/local/bin/aqua

FROM debian:13.5-slim@sha256:28de0877c2189802884ccd20f15ee41c203573bd87bb6b883f5f46362d24c5c2

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

COPY --from=docker:29.6.1-cli@sha256:862099ada15c669000bef53aa4cb9d821262829f45b0dda2159ccb276443043b /usr/local/bin/docker /usr/local/bin/docker
COPY --from=moby/buildkit:v0.31.1@sha256:6b59b7df63a8cb9902736f9ddf7fcff8261613d3e7449b8ea8b7537fc399c03a /usr/bin/buildctl /usr/local/bin/buildctl
COPY --from=mikefarah/yq:4.53.3@sha256:11a1f0b604b13dbbdc662260d8db6f644b22d8553122a25c1b5b2e8713ca6977 /usr/bin/yq /usr/local/bin/yq

COPY --from=aqua-cli /usr/local/bin/aqua /usr/local/bin/aqua
ADD --chown=1001:1001 https://github.com/aquaproj/aqua-registry.git#${AQUA_REGISTRY_VERSION} /opt/aqua-registry

RUN groupadd --gid 1001 runner \
    && useradd --uid 1001 --gid 1001 --create-home --shell /bin/bash runner \
    && mkdir --parents /home/runner/.local/share/aquaproj-aqua \
    && chown --recursive runner:runner /home/runner

COPY --from=runner-source --chown=runner:runner /opt/runner /home/runner/actions-runner

USER runner
WORKDIR /home/runner/actions-runner

ENV AQUA_ROOT_DIR=/home/runner/.local/share/aquaproj-aqua \
    AQUA_GLOBAL_CONFIG=/opt/aqua-registry/aqua-all.yaml \
    AQUA_DISABLE_POLICY=true \
    PATH=/usr/local/bin:/usr/bin:/bin:/home/runner/.local/share/aquaproj-aqua/bin

RUN aqua install --only-link --all

ENTRYPOINT ["./run.sh"]

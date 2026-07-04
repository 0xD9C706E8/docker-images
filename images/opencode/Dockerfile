# https://github.com/anomalyco/opencode

# renovate: datasource=npm depName=opencode-ai
ARG OPENCODE_AI_VERSION=1.17.12

# renovate: datasource=github-releases depName=aquaproj/aqua
ARG AQUA_VERSION=v2.60.1
# renovate: datasource=github-releases depName=aquaproj/aqua extractVersion=^v(?<version>.+)$
ARG AQUA_PKG_VERSION=2.60.1

# renovate: datasource=github-releases depName=aquaproj/aqua-registry
ARG AQUA_REGISTRY_VERSION=v4.530.0

FROM docker:29.6.1-cli@sha256:862099ada15c669000bef53aa4cb9d821262829f45b0dda2159ccb276443043b AS docker-cli

FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS aqua-cli
ARG AQUA_VERSION
ARG AQUA_PKG_VERSION
ARG TARGETARCH
ARG AQUA_ARCH=${TARGETARCH}

ADD "https://github.com/aquaproj/aqua/releases/download/${AQUA_VERSION}/aqua_${AQUA_PKG_VERSION}_checksums.txt" /tmp/checksums.txt
# hadolint ignore=DL3010
ADD "https://github.com/aquaproj/aqua/releases/download/${AQUA_VERSION}/aqua_linux_${AQUA_ARCH}.tar.gz" /tmp/aqua.tar.gz
RUN expected=$(awk -v "pat=aqua_linux_${AQUA_ARCH}.tar.gz" '$2 == pat {print $1; exit}' /tmp/checksums.txt) \
 && [ -n "${expected}" ] || { echo "missing checksum for aqua_linux_${AQUA_ARCH}.tar.gz" >&2; exit 1; } \
 && actual=$(sha256sum /tmp/aqua.tar.gz) \
 && actual=${actual%% *} \
 && [ "${expected}" = "${actual}" ] \
 && tar --extract --gzip --file=/tmp/aqua.tar.gz --directory=/tmp aqua \
 && install --mode=0755 /tmp/aqua /usr/local/bin/aqua

FROM node:24.18.0-trixie-slim@sha256:366fdef91728b1b7fa18c84fba63b6e79ed77b7e10cc206878e9705da4d7b169
ARG AQUA_REGISTRY_VERSION
ARG OPENCODE_AI_VERSION

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        libatomic1 \
        openssh-client \
 && rm -rf /var/lib/apt/lists/*

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx

COPY --from=aqua-cli /usr/local/bin/aqua /usr/local/bin/aqua
ADD "https://github.com/aquaproj/aqua-registry/archive/refs/tags/${AQUA_REGISTRY_VERSION}.tar.gz" /tmp/aqua-registry.tar.gz
RUN mkdir --parents /opt/aqua-registry \
 && tar --extract --gzip --file=/tmp/aqua-registry.tar.gz --directory=/opt/aqua-registry --strip-components=1

RUN userdel node \
 && groupadd --gid=1000 opencode \
 && useradd --uid=1000 --gid=1000 --create-home --shell=/bin/bash opencode \
 && mkdir --parents /home/opencode/.npm-global \
             /home/opencode/.local/share/aquaproj-aqua \
             /home/opencode/.docker \
             /home/opencode/.ssh \
 && chown --recursive opencode:opencode /home/opencode

USER opencode
WORKDIR /home/opencode
ENV HOME=/home/opencode \
    NPM_CONFIG_PREFIX=/home/opencode/.npm-global \
    OPENCODE_CONFIG_DIR=/home/opencode/.config/opencode \
    AQUA_ROOT_DIR=/home/opencode/.local/share/aquaproj-aqua \
    AQUA_GLOBAL_CONFIG=/opt/aqua-registry/aqua-all.yaml \
    PATH=/home/opencode/.npm-global/bin:/usr/local/bin:/usr/bin:/bin:/home/opencode/.local/share/aquaproj-aqua/bin \
    NODE_ENV=production
# Disable aqua's interactive package-source policy so headless installs
# work without a TTY. The registry is still pinned by version.
ENV AQUA_DISABLE_POLICY=true

RUN aqua install --only-link --all \
 && npm install --global "opencode-ai@${OPENCODE_AI_VERSION}"

EXPOSE 4096

ENTRYPOINT ["opencode"]
CMD ["serve", "--hostname", "0.0.0.0", "--port", "4096"]

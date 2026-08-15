# https://github.com/openchamber/openchamber

# renovate: datasource=github-releases depName=openchamber/openchamber
ARG OPENCHAMBER_VERSION=v1.18.4

# renovate: datasource=github-releases depName=aquaproj/aqua
ARG AQUA_VERSION=v2.62.3

# renovate: datasource=github-releases depName=aquaproj/aqua-registry
ARG AQUA_REGISTRY_VERSION=v4.551.0

# renovate: datasource=npm depName=opencode-ai
ARG OPENCODE_AI_VERSION=1.18.17

FROM docker:29.7.2-cli@sha256:000bb62ff495f986c9f5578eb67cc2cb98b91138eda81d7762d5371eb8a497fe AS docker-cli

FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS aqua-cli
ARG AQUA_VERSION
ARG AQUA_SHA256
ARG TARGETARCH

ADD --checksum=sha256:${AQUA_SHA256} --unpack=true \
    https://github.com/aquaproj/aqua/releases/download/${AQUA_VERSION}/aqua_linux_${TARGETARCH}.tar.gz \
    /tmp/
RUN install --mode=0755 /tmp/aqua /usr/local/bin/aqua

FROM oven/bun:1.3.14-slim@sha256:d56a2534ffd262e92c12fd3249d3924d296d97086da773f821d7d0477435ea04 AS source
ARG OPENCHAMBER_VERSION

ADD https://github.com/openchamber/openchamber.git#${OPENCHAMBER_VERSION} /src

FROM oven/bun:1.3.14-slim@sha256:d56a2534ffd262e92c12fd3249d3924d296d97086da773f821d7d0477435ea04 AS deps
WORKDIR /app

COPY --from=source /src/package.json /src/bun.lock ./
COPY --from=source /src/packages/ui/package.json ./packages/ui/
COPY --from=source /src/packages/web/package.json ./packages/web/
COPY --from=source /src/packages/electron/package.json ./packages/electron/
COPY --from=source /src/packages/vscode/package.json ./packages/vscode/
COPY --from=source /src/packages/mobile/package.json ./packages/mobile/
COPY --from=source /src/bun-patches ./bun-patches

RUN bun install --frozen-lockfile --ignore-scripts \
    && find /app -type d -name 'app-builder-bin' -prune -exec rm -rf {} +

FROM deps AS builder
COPY --from=source /src ./

RUN bun run build:web

FROM node:24.19.0-trixie-slim@sha256:0711b541c1c33a8a530ac4f0d391baa9a15b3d804695b1b24a47daa5fb60e74d
ARG AQUA_REGISTRY_VERSION
ARG OPENCODE_AI_VERSION

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

COPY --from=cloudflare/cloudflared:2026.8.2@sha256:0aa26e284f05e6c77ae375b8c9c11d9eb6a448fb7bcd8d40f31cb6176189eb38 /usr/local/bin/cloudflared /usr/local/bin/cloudflared

COPY --from=aqua-cli /usr/local/bin/aqua /usr/local/bin/aqua
ADD --chown=1000:1000 https://github.com/aquaproj/aqua-registry.git#${AQUA_REGISTRY_VERSION} /opt/aqua-registry

RUN userdel node \
    && groupadd --gid=1000 openchamber \
    && useradd --uid=1000 --gid=1000 --create-home --shell=/bin/bash openchamber \
    && mkdir --parents /home/openchamber/.npm-global \
    /home/openchamber/.local/share/aquaproj-aqua \
    /home/openchamber/.docker \
    /home/openchamber/.ssh \
    && chown --recursive 1000:1000 /home/openchamber

USER 1000
WORKDIR /home/openchamber

ENV HOME=/home/openchamber \
    NPM_CONFIG_PREFIX=/home/openchamber/.npm-global \
    AQUA_ROOT_DIR=/home/openchamber/.local/share/aquaproj-aqua \
    AQUA_GLOBAL_CONFIG=/opt/aqua-registry/aqua-all.yaml \
    AQUA_DISABLE_POLICY=true \
    PATH=/home/openchamber/.npm-global/bin:/usr/local/bin:/usr/bin:/bin:/home/openchamber/.local/share/aquaproj-aqua/bin \
    NODE_ENV=production

RUN aqua install --only-link --all

RUN npm config set prefix /home/openchamber/.npm-global \
    && npm install --global "opencode-ai@${OPENCODE_AI_VERSION}"

COPY --from=builder --chown=1000:1000 /app/node_modules ./node_modules
COPY --from=builder --chown=1000:1000 /app/packages/web/node_modules ./packages/web/node_modules
COPY --from=builder --chown=1000:1000 /app/package.json ./package.json
COPY --from=builder --chown=1000:1000 /app/packages/web/package.json ./packages/web/package.json
COPY --from=builder --chown=1000:1000 /app/packages/web/bin ./packages/web/bin
COPY --from=builder --chown=1000:1000 /app/packages/web/server ./packages/web/server
COPY --from=builder --chown=1000:1000 /app/packages/web/dist ./packages/web/dist

COPY --chown=1000:1000 rootfs/ /

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]

# https://github.com/openchamber/openchamber

# renovate: datasource=github-releases depName=openchamber/openchamber
ARG OPENCHAMBER_VERSION=v1.15.0

# renovate: datasource=github-releases depName=aquaproj/aqua
ARG AQUA_VERSION=v2.60.2

# renovate: datasource=github-releases depName=aquaproj/aqua-registry
ARG AQUA_REGISTRY_VERSION=v4.534.0

# renovate: datasource=npm depName=opencode-ai
ARG OPENCODE_AI_VERSION=1.17.18

FROM docker:29.6.1-cli@sha256:862099ada15c669000bef53aa4cb9d821262829f45b0dda2159ccb276443043b AS docker-cli

FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS aqua-cli
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
COPY --from=source /src/patches ./patches

RUN bun install --frozen-lockfile --ignore-scripts \
 && find /app -type d -name 'app-builder-bin' -prune -exec rm -rf {} +

FROM deps AS builder
COPY --from=source /src ./

RUN bun run build:web

FROM node:24.18.0-trixie-slim@sha256:366fdef91728b1b7fa18c84fba63b6e79ed77b7e10cc206878e9705da4d7b169
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

COPY --from=cloudflare/cloudflared:2026.7.1@sha256:188bb03589a32affed3cf4d0590565ffe67b78866e6b5582574afab2b705bafe /usr/local/bin/cloudflared /usr/local/bin/cloudflared

COPY --from=aqua-cli /usr/local/bin/aqua /usr/local/bin/aqua
ADD --chown=1000:1000 https://github.com/aquaproj/aqua-registry.git#${AQUA_REGISTRY_VERSION} /opt/aqua-registry

RUN userdel node \
 && groupadd --gid=1000 openchamber \
 && useradd --uid=1000 --gid=1000 --create-home --shell=/bin/bash openchamber \
 && mkdir --parents /home/openchamber/.npm-global \
             /home/openchamber/.local/share/aquaproj-aqua \
             /home/openchamber/.docker \
             /home/openchamber/.ssh \
 && chown --recursive openchamber:openchamber /home/openchamber

USER openchamber
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

COPY --from=builder --chown=openchamber:openchamber /app/node_modules ./node_modules
COPY --from=builder --chown=openchamber:openchamber /app/packages/web/node_modules ./packages/web/node_modules
COPY --from=builder --chown=openchamber:openchamber /app/package.json ./package.json
COPY --from=builder --chown=openchamber:openchamber /app/packages/web/package.json ./packages/web/package.json
COPY --from=builder --chown=openchamber:openchamber /app/packages/web/bin ./packages/web/bin
COPY --from=builder --chown=openchamber:openchamber /app/packages/web/server ./packages/web/server
COPY --from=builder --chown=openchamber:openchamber /app/packages/web/dist ./packages/web/dist

COPY --chown=openchamber:openchamber rootfs/ /

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]

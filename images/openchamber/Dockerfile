# https://github.com/openchamber/openchamber

# renovate: datasource=github-releases depName=openchamber/openchamber
ARG OPENCHAMBER_VERSION=v1.13.8

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

RUN bun install --frozen-lockfile --ignore-scripts \
 && find /app -type d -name 'app-builder-bin' -prune -exec rm -rf {} +

FROM deps AS builder
COPY --from=source /src ./

RUN bun run build:web

FROM node:24.18.0-trixie-slim@sha256:366fdef91728b1b7fa18c84fba63b6e79ed77b7e10cc206878e9705da4d7b169

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        libatomic1 \
        openssh-client \
 && rm -rf /var/lib/apt/lists/*

RUN userdel node \
 && groupadd --gid=1000 openchamber \
 && useradd --uid=1000 --gid=1000 --create-home --shell=/bin/bash openchamber \
 && mkdir --parents /home/openchamber/.ssh \
 && chown --recursive openchamber:openchamber /home/openchamber

USER openchamber
WORKDIR /home/openchamber

ENV HOME=/home/openchamber \
    PATH=/usr/local/bin:/usr/bin:/bin \
    NODE_ENV=production \
    OPENCODE_SKIP_START=true

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

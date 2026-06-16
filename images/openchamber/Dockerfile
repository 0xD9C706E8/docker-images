# https://github.com/btriapitsyn/openchamber

# renovate: datasource=github-releases depName=btriapitsyn/openchamber
ARG OPENCHAMBER_VERSION=v1.13.0

# renovate: datasource=github-releases depName=jdx/mise
ARG MISE_VERSION=v2026.6.10

# renovate: datasource=npm depName=opencode-ai
ARG OPENCODE_AI_VERSION=1.17.7

FROM docker:29.5.3-cli@sha256:11e1133c30f3ceb73c6bdc7dfb78b3f9ed8e8e0d1d0400e91c5ec2eb240bf2ff AS docker-cli

FROM oven/bun:1.3.14-slim@sha256:d56a2534ffd262e92c12fd3249d3924d296d97086da773f821d7d0477435ea04 AS source
ARG OPENCHAMBER_VERSION

ADD https://github.com/btriapitsyn/openchamber.git#${OPENCHAMBER_VERSION} /src

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
WORKDIR /app

COPY --from=source /src ./

RUN bun run build:web

FROM oven/bun:1.3.14-slim@sha256:d56a2534ffd262e92c12fd3249d3924d296d97086da773f821d7d0477435ea04
ARG MISE_VERSION
ARG TARGETARCH
ARG OPENCODE_AI_VERSION

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        less \
        nodejs \
        npm \
        openssh-client \
        python3 \
 && rm -rf /var/lib/apt/lists/*

RUN case "${TARGETARCH}" in \
        amd64) MISE_ARCH=x64 ;; \
        arm64) MISE_ARCH=arm64 ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac \
 && curl --silent --location --fail \
        --output /tmp/mise.tar.gz \
        "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-${MISE_ARCH}.tar.gz" \
 && tar --extract --gzip --file=/tmp/mise.tar.gz --directory=/tmp \
 && install --mode=0755 /tmp/mise/bin/mise /usr/local/bin/mise \
 && rm -rf /tmp/mise /tmp/mise.tar.gz \
 && /usr/local/bin/mise --version

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx

COPY --from=cloudflare/cloudflared:2026.6.0@sha256:ba461b8aa9c042156dbd39c38657fe7431bafa063220eab8d5330a523863da9f /usr/local/bin/cloudflared /usr/local/bin/cloudflared

RUN userdel bun \
 && groupadd --gid=1000 openchamber \
 && useradd --uid=1000 --gid=1000 --create-home --shell=/bin/bash openchamber \
 && mkdir --parents /home/openchamber/.npm-global \
             /home/openchamber/.local/share/mise \
             /home/openchamber/.config/mise \
             /home/openchamber/.docker \
             /home/openchamber/.ssh \
 && chown --recursive openchamber:openchamber /home/openchamber

USER openchamber
WORKDIR /home/openchamber

ENV HOME=/home/openchamber \
    NPM_CONFIG_PREFIX=/home/openchamber/.npm-global \
    MISE_DATA_DIR=/home/openchamber/.local/share/mise \
    MISE_CONFIG_DIR=/home/openchamber/.config/mise \
    PATH=/home/openchamber/.local/share/mise/shims:/home/openchamber/.npm-global/bin:/usr/local/bin:/usr/bin:/bin \
    NODE_ENV=production

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

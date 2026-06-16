# https://github.com/pocket-id/pocket-id

# renovate: datasource=github-releases depName=pocket-id/pocket-id
ARG POCKET_ID_VERSION=v2.9.0

FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS source
ARG POCKET_ID_VERSION

ADD https://github.com/pocket-id/pocket-id.git#${POCKET_ID_VERSION} /src

FROM node:24-alpine@sha256:21f403ab171f2dc89bad4dd69d7721bfd15f084ccb46cdd225f31f2bc59b5c9a AS frontend-builder
RUN corepack enable

WORKDIR /build

COPY --from=source /src/package.json /src/pnpm-workspace.yaml /src/pnpm-lock.yaml ./
COPY --from=source /src/frontend/package.json ./frontend/
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm --filter pocket-id-frontend install --frozen-lockfile

COPY --from=source /src/frontend ./frontend/

RUN --mount=type=cache,target=/build/frontend/node_modules/.vite \
    --mount=type=cache,target=/build/frontend/.svelte-kit \
    BUILD_OUTPUT_PATH=dist pnpm --filter pocket-id-frontend run build

FROM golang:1.26.4-alpine@sha256:f1ddd9fe14fffc091dd98cb4bfa999f32c5fc77d2f2305ea9f0e2595c5437c14 AS backend-builder
ARG TARGETOS
ENV CGO_ENABLED=0 GOOS=${TARGETOS}

WORKDIR /build

COPY --from=source /src/backend/go.mod /src/backend/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY --from=source /src/backend ./
COPY --from=frontend-builder /build/frontend/dist ./frontend/dist
COPY --from=source /src/.version .version

WORKDIR /build/cmd

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    VERSION=$(cat /build/.version) \
 && go build \
        -ldflags "-s -w \
            -X github.com/pocket-id/pocket-id/backend/internal/common.Version=${VERSION}" \
        -trimpath \
        -o /pocket-id \
        .

FROM gcr.io/distroless/static-debian12:nonroot@sha256:d093aa3e30dbadd3efe1310db061a14da60299baff8450a17fe0ccc514a16639

WORKDIR /app

COPY --from=backend-builder /pocket-id /usr/local/bin/pocket-id

ENV APP_ENV=production

EXPOSE 1411

HEALTHCHECK --interval=90s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/usr/local/bin/pocket-id", "healthcheck"]

ENTRYPOINT ["/usr/local/bin/pocket-id"]

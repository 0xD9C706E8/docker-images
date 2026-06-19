# https://github.com/pocket-id/pocket-id

# renovate: datasource=github-releases depName=pocket-id/pocket-id
ARG POCKET_ID_VERSION=v2.9.0

FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS source
ARG POCKET_ID_VERSION

ADD https://github.com/pocket-id/pocket-id.git#${POCKET_ID_VERSION} /src

FROM node:24-alpine@sha256:156b55f92e98ccd5ef49578a8cea0df4679826564bad1c9d4ef04462b9f0ded6 AS frontend-builder
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

FROM golang:1.26.4-alpine@sha256:3ad57304ad93bbec8548a0437ad9e06a455660655d9af011d58b993f6f615648 AS backend-builder
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

# https://github.com/tinyauthapp/tinyauth

# renovate: datasource=github-releases depName=tinyauthapp/tinyauth
ARG TINYAUTH_VERSION=v5.1.0

FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS source
ARG TINYAUTH_VERSION

ADD https://github.com/tinyauthapp/tinyauth.git#${TINYAUTH_VERSION} /src

FROM oven/bun:1.3.14-alpine@sha256:5acc90a93e91ff07bf72aa90a7c9f0fa189765aec90b47bdbf2152d2196383c0 AS frontend-builder

COPY --from=source /src /src
WORKDIR /src/frontend

RUN bun install --frozen-lockfile \
    && bun run build

FROM golang:1.26.5-alpine@sha256:0178a641fbb4858c5f1b48e34bdaabe0350a330a1b1149aabd498d0699ff5fb2 AS builder
ARG TINYAUTH_VERSION

COPY --from=source /src /src
COPY --from=frontend-builder /src/frontend/dist /src/internal/assets/dist
WORKDIR /src

RUN go mod download \
    && CGO_ENABLED=0 GOOS=linux go build \
        -ldflags "-s -w -X github.com/steveiliop56/tinyauth/internal/config.Version=${TINYAUTH_VERSION}" \
        -trimpath \
        -o /tinyauth \
        ./cmd/tinyauth

FROM gcr.io/distroless/static-debian12:nonroot@sha256:aef9602f8710ec12bde19d593fed1f76c708531bb7aba205110f1029786ead7b

COPY --from=builder /tinyauth /usr/local/bin/tinyauth

ENV TINYAUTH_DATABASE_PATH=/data/tinyauth.db \
    TINYAUTH_RESOURCES_PATH=/data/resources

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["/usr/local/bin/tinyauth", "healthcheck"]

ENTRYPOINT ["/usr/local/bin/tinyauth"]

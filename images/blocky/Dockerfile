# https://github.com/0xERR0R/blocky

# renovate: datasource=github-releases depName=0xERR0R/blocky
ARG BLOCKY_VERSION=v0.31.0

FROM alpine:3.24@sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4 AS source
ARG BLOCKY_VERSION

RUN apk add --no-cache git \
    && git clone --depth 1 --branch ${BLOCKY_VERSION} https://github.com/0xERR0R/blocky.git /src

FROM golang:1.26-alpine@sha256:7a3e50096189ad57c9f9f865e7e4aa8585ed1585248513dc5cda498e2f41812c AS builder
ARG BLOCKY_VERSION

COPY --from=source /src /src
WORKDIR /src

RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux go build \
        -tags static \
        -ldflags "-s -w \
            -X github.com/0xERR0R/blocky/util.Version=${BLOCKY_VERSION} \
            -X github.com/0xERR0R/blocky/util.BuildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        -trimpath \
        -o /blocky \
        .

FROM gcr.io/distroless/static-debian12:nonroot@sha256:d093aa3e30dbadd3efe1310db061a14da60299baff8450a17fe0ccc514a16639

WORKDIR /app

COPY --from=builder /blocky /usr/local/bin/blocky

ENV BLOCKY_CONFIG_FILE=/app/config.yml

EXPOSE 53/tcp 53/udp 4000/tcp

HEALTHCHECK --interval=1m --timeout=3s --start-period=10s --retries=3 \
    CMD ["/usr/local/bin/blocky", "healthcheck"]

ENTRYPOINT ["/usr/local/bin/blocky"]
CMD ["serve"]

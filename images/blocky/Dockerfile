# https://github.com/0xERR0R/blocky

# renovate: datasource=github-releases depName=0xERR0R/blocky
ARG BLOCKY_VERSION=v0.32.0

FROM golang:1.26-alpine@sha256:f1ddd9fe14fffc091dd98cb4bfa999f32c5fc77d2f2305ea9f0e2595c5437c14 AS builder
ARG BLOCKY_VERSION
ARG TARGETOS
ENV CGO_ENABLED=0 GOOS=${TARGETOS}

ADD https://github.com/0xERR0R/blocky.git#${BLOCKY_VERSION} /src
WORKDIR /src

RUN go mod download

RUN go build \
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

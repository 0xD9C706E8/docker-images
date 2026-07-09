# https://github.com/0xERR0R/blocky

# renovate: datasource=github-releases depName=0xERR0R/blocky
ARG BLOCKY_VERSION=v0.33.0

FROM golang:1.26.4-alpine@sha256:3ad57304ad93bbec8548a0437ad9e06a455660655d9af011d58b993f6f615648 AS builder
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

FROM gcr.io/distroless/static-debian12:nonroot@sha256:b7bb25d9f7c31d2bdd1982feb4dafcaf137703c7075dbe2febb41c24212b946f

WORKDIR /app

COPY --from=builder /blocky /usr/local/bin/blocky

ENV BLOCKY_CONFIG_FILE=/app/config.yml

EXPOSE 53/tcp 53/udp 4000/tcp

HEALTHCHECK --interval=1m --timeout=3s --start-period=10s --retries=3 \
    CMD ["/usr/local/bin/blocky", "healthcheck"]

ENTRYPOINT ["/usr/local/bin/blocky"]
CMD ["serve"]

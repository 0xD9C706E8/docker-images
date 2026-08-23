# https://github.com/0xERR0R/blocky

# renovate: datasource=github-releases depName=0xERR0R/blocky
ARG BLOCKY_VERSION=v0.34.0

FROM golang:1.27.0-alpine@sha256:4c9fe60190a2a3350ddc51de80d0224b8a6698d12bdfc999fee45ea9d6c46dbc AS builder
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

FROM gcr.io/distroless/static-debian12:nonroot@sha256:aef9602f8710ec12bde19d593fed1f76c708531bb7aba205110f1029786ead7b

WORKDIR /app

COPY --from=builder /blocky /usr/local/bin/blocky

ENV BLOCKY_CONFIG_FILE=/app/config.yml

EXPOSE 53/tcp 53/udp 4000/tcp

HEALTHCHECK --interval=1m --timeout=3s --start-period=10s --retries=3 \
    CMD ["/usr/local/bin/blocky", "healthcheck"]

ENTRYPOINT ["/usr/local/bin/blocky"]
CMD ["serve"]

# https://github.com/lldap/lldap

# renovate: datasource=github-releases depName=lldap/lldap
ARG LLDAP_VERSION=v0.6.3

# renovate: datasource=github-releases depName=rustwasm/wasm-pack
ARG WASM_PACK_VERSION=0.15.0

# renovate: datasource=github-releases depName=rustwasm/wasm-bindgen
ARG WASM_BINDGEN_VERSION=0.2.125

FROM alpine:3.24@sha256:f5064d3e5f88c467c714509f491853ab2d951932c5cad699c0cb969dcec6f3b4 AS source
ARG LLDAP_VERSION

ADD https://github.com/lldap/lldap.git#${LLDAP_VERSION} /src

FROM rust:alpine3.21@sha256:7dba3db75b0d5861af2e5dcf5b87347411e84403b5c9835be00ef1e72e299d2a AS builder

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

RUN addgroup -g 1000 app \
 && adduser -u 1000 -G app -D -h /app app \
 && apk add --no-cache \
        cmake \
        curl \
        gzip \
        make \
        musl-dev \
        nasm \
        openssl-dev \
        perl
ARG WASM_PACK_VERSION
ARG WASM_BINDGEN_VERSION
ARG TARGETARCH

RUN case "${TARGETARCH}" in \
        amd64) ARCH="x86_64" ;; \
        arm64) ARCH="aarch64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac \
 && curl -L "https://github.com/rustwasm/wasm-pack/releases/download/v${WASM_PACK_VERSION}/wasm-pack-v${WASM_PACK_VERSION}-${ARCH}-unknown-linux-musl.tar.gz" | tar xz -C /tmp \
 && mv "/tmp/wasm-pack-v${WASM_PACK_VERSION}-${ARCH}-unknown-linux-musl/wasm-pack" /usr/local/bin/ \
 && curl -L "https://github.com/rustwasm/wasm-bindgen/releases/download/${WASM_BINDGEN_VERSION}/wasm-bindgen-${WASM_BINDGEN_VERSION}-${ARCH}-unknown-linux-musl.tar.gz" | tar xz -C /tmp \
 && mv "/tmp/wasm-bindgen-${WASM_BINDGEN_VERSION}-${ARCH}-unknown-linux-musl/wasm-bindgen" /usr/local/bin/ \
 && rustup target add wasm32-unknown-unknown

USER app
WORKDIR /app

COPY --from=source --chown=app:app /src .

RUN --mount=type=cache,target=/app/.cargo/registry,id=cargo-registry-${TARGETARCH},uid=1000,gid=1000 \
    --mount=type=cache,target=/app/target,id=cargo-target-${TARGETARCH},uid=1000,gid=1000 \
    cargo build --release \
        -p lldap \
        -p lldap_migration_tool \
        -p lldap_set_password \
 && ./app/build.sh \
 && mkdir -p /app/bin \
 && cp /app/target/release/lldap /app/bin/ \
 && cp /app/target/release/lldap_migration_tool /app/bin/ \
 && cp /app/target/release/lldap_set_password /app/bin/ \
 && while IFS= read -r url; do curl --silent --location --output "/app/app/static/$(basename "$url")" "$url"; done < /app/app/static/libraries.txt \
 && while IFS= read -r url; do curl --silent --location --output "/app/app/static/fonts/$(basename "$url")" "$url"; done < /app/app/static/fonts/fonts.txt

FROM alpine:3.24@sha256:f5064d3e5f88c467c714509f491853ab2d951932c5cad699c0cb969dcec6f3b4

RUN addgroup -g 1000 lldap \
 && adduser -u 1000 -G lldap -D -H -s /sbin/nologin lldap \
 && apk add --no-cache tzdata \
 && mkdir -p /app /data \
 && chown lldap:lldap /data

WORKDIR /app

COPY --from=builder --chown=lldap:lldap /app/app/index_local.html app/index.html
COPY --from=builder --chown=lldap:lldap /app/app/static app/static
COPY --from=builder --chown=lldap:lldap /app/app/pkg app/pkg
COPY --from=builder --chown=lldap:lldap /app/bin/lldap /app/bin/lldap_migration_tool /app/bin/lldap_set_password ./
COPY --from=source --chown=lldap:lldap /src/lldap_config.docker_template.toml ./

USER lldap

ENV LDAP_PORT=3890
ENV HTTP_PORT=17170

EXPOSE 3890 17170

HEALTHCHECK CMD ["/app/lldap", "healthcheck", "--config-file", "/data/lldap_config.toml"]

ENTRYPOINT ["/app/lldap"]
CMD ["run", "--config-file", "/data/lldap_config.toml"]

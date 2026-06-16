# https://github.com/lldap/lldap

# renovate: datasource=github-releases depName=lldap/lldap
ARG LLDAP_VERSION=v0.6.3

# renovate: datasource=github-releases depName=rustwasm/wasm-pack
ARG WASM_PACK_VERSION=0.15.0

FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS source
ARG LLDAP_VERSION

ADD https://github.com/lldap/lldap.git#${LLDAP_VERSION} /src

FROM rust:alpine3.24@sha256:f87aa870663e2b57ec8c69de82c7eedf7383bee987eef7612c0359635eaadb41 AS builder

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
ARG TARGETARCH

RUN rustup target add wasm32-unknown-unknown

# Three coupled constraints:
# - wasm-bindgen-cli version: must match lldap's Cargo.lock (wasm-pack enforces)
# - cargo install (not prebuilt tarball): rustwasm/wasm-pack#1416 broken on Alpine arm64
# - RUSTFLAGS=-Ctarget-feature=-crt-static: rust-lang/rust#115450 (link openssl-dev dynamic)
RUN --mount=type=bind,from=source,source=/src/Cargo.lock,target=/tmp/Cargo.lock \
    WASM_BINDGEN_VERSION="$(awk '/^name = "wasm-bindgen"$/{getline; print}' /tmp/Cargo.lock | sed -n 's/^version = "\(.*\)"/\1/p')" \
 && [ -n "${WASM_BINDGEN_VERSION}" ] || { echo 'failed to extract wasm-bindgen version from Cargo.lock' >&2; exit 1; } \
 && export CARGO_HOME=/tmp/cargo-bootstrap RUSTFLAGS="-Ctarget-feature=-crt-static" \
 && cargo install wasm-pack --locked --version "${WASM_PACK_VERSION}" --root /usr/local \
 && cargo install wasm-bindgen-cli --locked --version "${WASM_BINDGEN_VERSION}" --root /usr/local \
 && rm -rf /tmp/cargo-bootstrap

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

FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

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

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["/app/lldap", "healthcheck", "--config-file", "/data/lldap_config.toml"]

ENTRYPOINT ["/app/lldap"]
CMD ["run", "--config-file", "/data/lldap_config.toml"]

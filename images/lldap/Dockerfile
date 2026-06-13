# https://github.com/lldap/lldap

# renovate: datasource=github-releases depName=lldap/lldap
ARG LLDAP_VERSION=v0.6.3

# renovate: datasource=github-releases depName=rustwasm/wasm-bindgen
ARG WASM_BINDGEN_VERSION=0.2.120

FROM alpine:3.21@sha256:48b0309ca019d89d40f670aa1bc06e426dc0931948452e8491e3d65087abc07d AS source
ARG LLDAP_VERSION

ADD https://github.com/lldap/lldap/archive/refs/tags/${LLDAP_VERSION}.tar.gz /tmp/lldap.tar.gz

RUN mkdir -p /src \
 && tar xzf /tmp/lldap.tar.gz -C /src --strip-components=1

FROM rust:alpine3.21@sha256:7dba3db75b0d5861af2e5dcf5b87347411e84403b5c9835be00ef1e72e299d2a AS builder

RUN addgroup -g 1000 app \
 && adduser -u 1000 -G app -D -h /app app \
 && apk add --no-cache \
        curl \
        gzip \
        make \
        musl-dev \
        openssl-dev \
        perl

USER app
WORKDIR /app

ARG WASM_BINDGEN_VERSION
RUN cargo install wasm-pack \
 && cargo install wasm-bindgen-cli --version ${WASM_BINDGEN_VERSION} \
 && rustup target add wasm32-unknown-unknown

COPY --from=source --chown=app:app /src .

RUN cargo build --release \
        -p lldap \
        -p lldap_migration_tool \
        -p lldap_set_password \
 && ./app/build.sh

FROM alpine:3.21@sha256:48b0309ca019d89d40f670aa1bc06e426dc0931948452e8491e3d65087abc07d

RUN addgroup -g 1000 lldap \
 && adduser -u 1000 -G lldap -D -H -s /sbin/nologin lldap \
 && apk add --no-cache tzdata \
 && mkdir -p /app /data \
 && chown lldap:lldap /data

WORKDIR /app

COPY --from=builder --chown=lldap:lldap /app/app/index_local.html app/index.html
COPY --from=builder --chown=lldap:lldap /app/app/static app/static
COPY --from=builder --chown=lldap:lldap /app/app/pkg app/pkg
COPY --from=builder --chown=lldap:lldap /app/target/release/lldap /app/target/release/lldap_migration_tool /app/target/release/lldap_set_password ./
COPY --from=source --chown=lldap:lldap /src/lldap_config.docker_template.toml ./

RUN while IFS= read -r url; do wget --quiet -P app/static "$url"; done < app/static/libraries.txt \
 && while IFS= read -r url; do wget --quiet -P app/static/fonts "$url"; done < app/static/fonts/fonts.txt \
 && chmod a+r -R .

USER lldap

ENV LDAP_PORT=3890
ENV HTTP_PORT=17170

EXPOSE 3890 17170

HEALTHCHECK CMD ["/app/lldap", "healthcheck", "--config-file", "/data/lldap_config.toml"]

ENTRYPOINT ["/app/lldap"]
CMD ["run", "--config-file", "/data/lldap_config.toml"]

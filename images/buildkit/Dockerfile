# https://github.com/moby/buildkit

# renovate: datasource=github-releases depName=moby/buildkit
ARG BUILDKIT_VERSION=v0.30.0

# renovate: datasource=github-releases depName=opencontainers/runc
ARG RUNC_VERSION=v1.4.3

# renovate: datasource=github-releases depName=rootless-containers/rootlesskit
ARG ROOTLESSKIT_VERSION=v3.0.1

FROM golang:1.26-alpine@sha256:f1ddd9fe14fffc091dd98cb4bfa999f32c5fc77d2f2305ea9f0e2595c5437c14 AS gobuild-base
RUN apk add --no-cache musl-dev

FROM gobuild-base AS runc
ARG RUNC_VERSION
ARG TARGETOS
ENV CGO_ENABLED=1 GOOS=${TARGETOS}

RUN apk add --no-cache gcc libseccomp-dev libseccomp-static

ADD https://github.com/opencontainers/runc.git#${RUNC_VERSION} /src
WORKDIR /src

RUN go build \
        -ldflags "-s -w -extldflags -static" \
        -tags "apparmor seccomp netgo cgo static_build osusergo" \
        -trimpath \
        -o /usr/bin/runc \
        . \
 && /usr/bin/runc --version

FROM gobuild-base AS buildkit
ARG BUILDKIT_VERSION
ARG TARGETOS
ENV CGO_ENABLED=0 GOOS=${TARGETOS}

ADD https://github.com/moby/buildkit.git#${BUILDKIT_VERSION} /src
WORKDIR /src

RUN go build \
        -ldflags "-s -w \
            -X github.com/moby/buildkit/version.Version=${BUILDKIT_VERSION} \
            -X github.com/moby/buildkit/version.Package=github.com/moby/buildkit" \
        -tags "osusergo netgo static_build seccomp" \
        -trimpath \
        -o /usr/bin/buildkitd \
        ./cmd/buildkitd \
 && /usr/bin/buildkitd --version

RUN go build \
        -ldflags "-s -w \
            -X github.com/moby/buildkit/version.Version=${BUILDKIT_VERSION} \
            -X github.com/moby/buildkit/version.Package=github.com/moby/buildkit" \
        -trimpath \
        -o /usr/bin/buildctl \
        ./cmd/buildctl \
 && /usr/bin/buildctl --version

FROM gobuild-base AS rootlesskit
ARG ROOTLESSKIT_VERSION
ARG TARGETOS
ENV CGO_ENABLED=0 GOOS=${TARGETOS}

ADD https://github.com/rootless-containers/rootlesskit.git#${ROOTLESSKIT_VERSION} /src
WORKDIR /src

RUN go build \
        -ldflags "-s -w" \
        -trimpath \
        -o /usr/bin/rootlesskit \
        ./cmd/rootlesskit \
 && /usr/bin/rootlesskit --version

FROM alpine:3.24@sha256:f5064d3e5f88c467c714509f491853ab2d951932c5cad699c0cb969dcec6f3b4

RUN apk add --no-cache \
        fuse-overlayfs \
        fuse3 \
        git \
        openssh-client \
        pigz \
        shadow-uidmap \
        xz \
 && adduser -D -u 1000 user \
 && mkdir -p /run/user/1000 /home/user/.local/tmp /home/user/.local/share/buildkit \
 && chown -R user /run/user/1000 /home/user \
 && printf 'user:100000:65536\n' > /etc/subuid \
 && printf 'user:100000:65536\n' > /etc/subgid

COPY --from=runc /usr/bin/runc /usr/bin/runc
COPY --from=rootlesskit /usr/bin/rootlesskit /usr/bin/rootlesskit
COPY --from=buildkit /usr/bin/buildkitd /usr/bin/buildkitd
COPY --from=buildkit /usr/bin/buildctl /usr/bin/buildctl
COPY --from=buildkit /src/examples/buildctl-daemonless/buildctl-daemonless.sh /usr/bin/buildctl-daemonless.sh

USER 1000:1000

ENV HOME=/home/user \
    USER=user \
    XDG_RUNTIME_DIR=/run/user/1000 \
    TMPDIR=/home/user/.local/tmp \
    BUILDKIT_HOST=unix:///run/user/1000/buildkit/buildkitd.sock

EXPOSE 1234

ENTRYPOINT ["rootlesskit", "buildkitd"]

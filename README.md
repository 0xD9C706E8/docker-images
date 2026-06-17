# docker-images

Custom container images for my homelab. Rootless where possible, distroless where it makes sense, automated end to end.

[![Build](https://github.com/0xD9C706E8/docker-images/actions/workflows/build.yaml/badge.svg)](https://github.com/0xD9C706E8/docker-images/actions/workflows/build.yaml)
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen)](https://docs.renovatebot.com/)

This repo bakes opinionated containers for the apps I actually run at home. Nothing fancy under the hood, just Dockerfiles, GitHub Actions, and Renovate doing the heavy lifting. If any of these images happens to fit your homelab too, help yourself.

## What's in the box

<!-- image-table:start -->

<!-- prettier-ignore-start -->

| Image | Upstream | Base | Arches | Description | License |
| --- | --- | --- | --- | --- | --- |
| [actions-runner](images/actions-runner/) | [actions/runner](https://github.com/actions/runner) | debian-slim | amd64, arm64 | Rootless GitHub Actions self-hosted runner backed by remote BuildKit | MIT |
| [blocky](images/blocky/) | [0xERR0R/blocky](https://github.com/0xERR0R/blocky) | distroless static | amd64, arm64 | Rootless DNS proxy and ad-blocker for the home network | Apache-2.0 |
| [buildkit](images/buildkit/) | [moby/buildkit](https://github.com/moby/buildkit) | alpine | amd64, arm64 | Rootless BuildKit daemon for remote builds from in-cluster clients | Apache-2.0 |
| [lldap](images/lldap/) | [lldap/lldap](https://github.com/lldap/lldap) | alpine | amd64, arm64 | Light LDAP server backed by SQLite/MariaDB/Postgres | GPL-3.0 |
| [openchamber](images/openchamber/) | [openchamber/openchamber](https://github.com/openchamber/openchamber) | oven/bun (debian) | amd64, arm64 | OpenChamber web UI for OpenCode with aqua-managed CLI toolchain and remote BuildKit client | MIT |
| [pocket-id](images/pocket-id/) | [pocket-id/pocket-id](https://github.com/pocket-id/pocket-id) | distroless static | amd64, arm64 | Rootless OIDC provider with passkey authentication | BSD-2-Clause |
| [tinyauth](images/tinyauth/) | [tinyauthapp/tinyauth](https://github.com/tinyauthapp/tinyauth) | distroless static | amd64, arm64 | Rootless forward-auth and OIDC gateway for reverse proxies | AGPL-3.0 |

<!-- prettier-ignore-end -->

<!-- image-table:end -->

All images publish to `ghcr.io/0xd9c706e8/<app>` and tag as `:1`, `:1.2`, `:1.2.3`, and `:latest`. My downstream K8s manifests pin by digest via Renovate, so `:latest` is convenient for browsing but not what production tracks.

## What I optimized for

A few things I cared about that you might too.

**Smallest sane base image.** Go-only apps go to `gcr.io/distroless/static-debian12:nonroot`. Anything that needs glibc, Python, PHP, or a real init goes to a slim Debian or Alpine. No "ubuntu:latest with build tools left in" surprises.

**Rootless by default.** Every image runs as a non-root UID. Distroless ones are `nonroot` (65532). Everything else explicitly creates UID 1000:1000 with `/usr/sbin/nologin`. No image starts as root and `USER` switches mid-build.

**Pure-Go SQLite where the upstream allows it.** `CGO_ENABLED=0` for every Go build, using `modernc.org/sqlite` or `glebarez/go-sqlite`. That's how the distroless static images stay distroless.

**Reproducible-ish.** `-ldflags "-s -w" -trimpath` for Go binaries, multi-stage builds with build-time deps stripped from the final layer. No `*-dev` packages making it into runtime images.

**Automated updates.** Renovate watches every `ARG *_VERSION=` annotation and opens PRs when upstream releases. Auto-merges them too.

**Pinned everything.** Every GitHub Action is pinned by commit SHA with a `# vN` trailing comment. Every base image gets digest-pinned by Renovate.

**Multi-arch by default.** Every image builds for `linux/amd64` + `linux/arm64` and publishes a single manifest. An `image.yaml` per image directory can override the platform list when an upstream is single-arch only.

**Built on every push, every Sunday, on demand.** The `build.yaml` workflow builds only the images whose Dockerfiles changed, plus a weekly full rebuild to pick up base-image security updates that didn't bump a tag. PR checks push by digest only — no tags, just a scannable manifest reference for Trivy and a pull command in the run summary.

## Using these images

Pull whichever one you want and point your manifests at it. Tags and digest pins are all on the [GHCR package page](https://github.com/0xD9C706E8?tab=packages).

## Contributing

PRs welcome. If something is broken, an upstream changed shape, or you spotted a security issue, open an issue or send a PR and I will have a look :eyes:

## Caveats

These images are tuned for my K8s cluster. They run rootless, expect K8s-style mounts (no `VOLUME` directives), and assume a few things about networking that may not match your setup. Use at your own risk and read the Dockerfile before pulling :see_no_evil:

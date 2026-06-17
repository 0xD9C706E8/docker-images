# actions-runner

Rootless image for the [GitHub Actions self-hosted runner](https://github.com/actions/runner), wired for ephemeral deployment via [actions-runner-controller](https://github.com/actions/actions-runner-controller) (ARC) and remote container builds via [BuildKit](https://github.com/moby/buildkit).

## Deployment model

Designed for the ARC `gha-runner-scale-set` Helm chart in ephemeral mode. ARC injects the registration token through `ACTIONS_RUNNER_INPUT_JITCONFIG`; the runner consumes it directly, executes one job, then exits so the pod is garbage-collected.

```yaml
# values.yaml for gha-runner-scale-set
template:
  spec:
    containers:
      - name: runner
        image: ghcr.io/0xd9c706e8/actions-runner:1
```

Long-lived static deployments without ARC require a wrapper script that calls `config.sh` for registration; that path is intentionally not supported by this image.

## BuildKit wiring

The image bundles `docker` (CLI only, no daemon) and `buildctl` so workflows can build and push images without DinD or privileged mode. Set `BUILDKIT_HOST` to the in-cluster gRPC endpoint, e.g. `tcp://buildkit:1234` for [`ghcr.io/0xd9c706e8/buildkit`](../buildkit/).

| Variable        | Default | Purpose                                        |
| --------------- | ------- | ---------------------------------------------- |
| `BUILDKIT_HOST` | (unset) | gRPC endpoint for `docker buildx` / `buildctl` |

The BuildKit daemon enforces mTLS on remote TCP. Mount a Kubernetes Secret carrying the trio at `/etc/buildkit/certs/`:

| Path                           | Content            |
| ------------------------------ | ------------------ |
| `/etc/buildkit/certs/ca.pem`   | BuildKit CA cert   |
| `/etc/buildkit/certs/cert.pem` | Runner client cert |
| `/etc/buildkit/certs/key.pem`  | Runner client key  |

Workflows pass these to `buildctl` via `--tlscacert` / `--tlscert` / `--tlskey`, or to `docker buildx` via a builder context.

## Volumes

| Path                   | Use                                              |
| ---------------------- | ------------------------------------------------ |
| `/home/runner/_work`   | Runner work directory (job checkouts, artifacts) |
| `/etc/buildkit/certs/` | Read-only mTLS material (Secret mount)           |

## Bundled tooling

`bash`, `git`, `curl`, `ca-certificates`, `jq`, `yq`, `make`, `gh`, `docker` (CLI), `buildctl`. Workflows that need language toolchains install them per-job via the standard `setup-*` actions.

## Healthcheck

None. Ephemeral pods exit on completion; ARC manages liveness and replaces failed pods.

## Image size note

Heavier than peers in this repo (~150 MB compressed) because the runner is a dynamically linked .NET 8 application that requires glibc. Alpine and distroless cannot host it.

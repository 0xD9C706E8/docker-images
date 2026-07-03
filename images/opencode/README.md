# opencode

Image for the [OpenCode](https://opencode.ai) AI agent runtime. Provides a headless `opencode serve` server that any OpenCode client can connect to over HTTP. Adds an `aqua`-managed CLI toolchain and a `docker buildx` remote-builder client so an OpenCode session can lazy-install ~2000 CLI tools on demand and build container images against an external rootless BuildKit without `--privileged` or a docker socket.

## Composition

- `docker-cli` stage: extracts the docker CLI + buildx plugin.
- `aqua-cli` stage: downloads the `aqua` binary for the target architecture.
- `runtime` stage: `node:24-trixie-slim` with `aqua`, `aqua-registry`, docker CLI + buildx, and globally-installed `opencode-ai`.

Three Renovate-tracked pins:

- `OPENCODE_AI_VERSION` — opencode-ai npm package installed globally (npm datasource).
- `AQUA_VERSION` — aqua binary release (github-releases datasource).
- `AQUA_REGISTRY_VERSION` — aqua-registry release providing the global package catalog (github-releases datasource).

## What ships at runtime

- `opencode serve` bound to `:4096` by default.
- `aqua` with the standard registry pre-linked. No per-project `aqua.yaml` is required.
- `docker` CLI + `docker buildx` plugin. The Docker daemon is external.
- `opencode-ai` installed globally so the server can spawn agent sessions.

## Running

The container runs `opencode serve` bound to `0.0.0.0:4096` by default. Override with `command:` or by replacing the `CMD` entirely.

### Docker Compose

```yaml
services:
  opencode:
    image: ghcr.io/0xd9c706e8/opencode:1
    ports:
      - '4096:4096'
    environment:
      OPENCODE_SERVER_PASSWORD: ${OPENCODE_SERVER_PASSWORD:?Set before exposing}
    volumes:
      - ./data/opencode/share:/home/opencode/.local/share/opencode
      - ./data/opencode/state:/home/opencode/.local/state/opencode
      - ./data/opencode/config:/home/opencode/.config/opencode
      - ./data/ssh:/home/opencode/.ssh
      - ./data/aqua:/home/opencode/.local/share/aquaproj-aqua
      - ./workspaces:/home/opencode/workspaces
```

# Ensure ./data/ssh is owned by UID 1000 and keys are mode 0400.

Remote BuildKit (or any external Docker daemon) can be used by configuring `docker buildx` in an init container or sidecar; this image only ships the client.

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: opencode
spec:
  replicas: 1
  selector:
    matchLabels:
      app: opencode
  template:
    metadata:
      labels:
        app: opencode
    spec:
      securityContext:
        fsGroup: 1000
      containers:
        - name: opencode
          image: ghcr.io/0xd9c706e8/opencode:1
          ports:
            - containerPort: 4096
          env:
            - name: OPENCODE_SERVER_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: opencode
                  key: server-password
          volumeMounts:
            - name: opencode-share
              mountPath: /home/opencode/.local/share/opencode
            - name: opencode-state
              mountPath: /home/opencode/.local/state/opencode
            - name: opencode-config
              mountPath: /home/opencode/.config/opencode
            - name: aqua-cache
              mountPath: /home/opencode/.local/share/aquaproj-aqua
            - name: workspaces
              mountPath: /home/opencode/workspaces
            - name: ssh
              mountPath: /home/opencode/.ssh
      volumes:
        # Persistent volumes for the rest are deployment-shaped (PVC vs hostPath)
        - name: ssh
          secret:
            secretName: opencode-ssh
            defaultMode: 0400
```

## Volumes

| Path                                        | Use                                           |
| ------------------------------------------- | --------------------------------------------- |
| `/home/opencode/.config/opencode`           | OpenCode config                               |
| `/home/opencode/.local/share/opencode`      | OpenCode shared state                         |
| `/home/opencode/.local/state/opencode`      | OpenCode local state                          |
| `/home/opencode/.ssh`                       | SSH keys for git operations                   |
| `/home/opencode/.local/share/aquaproj-aqua` | aqua tool cache (lazy-installed CLI binaries) |
| `/home/opencode/workspaces`                 | Project worktrees                             |

## Ports

| Port     | Service         |
| -------- | --------------- |
| 4096/tcp | OpenCode server |

## Environment

| Variable                   | Effect                                                                          |
| -------------------------- | ------------------------------------------------------------------------------- |
| `OPENCODE_SERVER_PASSWORD` | HTTP basic-auth password for `opencode serve`. Username defaults to `opencode`. |
| `OPENCODE_SERVER_USERNAME` | Override the basic-auth username for `opencode serve`. Defaults to `opencode`.  |

## Security

- Runs as UID/GID 1000:1000 (`opencode`).

## Dev toolchains via aqua

The image ships [aqua](https://aquaproj.github.io) wired against the [aqua-registry](https://github.com/aquaproj/aqua-registry) standard catalog. At build time, `aqua install --only-link --all` pre-creates hardlinks for every package; at runtime, the first invocation downloads the registry's pinned version.

- `go`, `uv`, `rustup-init`, `terraform`, `kubectl`, `helm`, `gh`, `jq`, `yq`, and ~2000 other CLI tools resolve cleanly via aqua without any per-project config. `node`, `npm`, and `npx` come from the Node.js 24 LTS base image.
- Python is installed via `uv` (e.g. `uv python install 3.13` or `uv run python script.py`). The image does not ship a system Python.
- Rust is bootstrapped on first use via `rustup-init -y --no-modify-path && source ~/.cargo/env`.
- `AQUA_DISABLE_POLICY=true` is set so lazy installs don't require interactive policy approval.

The aqua cache at `/home/opencode/.local/share/aquaproj-aqua` should be a persistent volume — without it, every restart re-downloads installed binaries. PATH order puts `~/.npm-global/bin` before aqua's bin dir, so the npm-installed `opencode-ai@${OPENCODE_AI_VERSION}` wins over aqua's `anomalyco/opencode` hardlink.

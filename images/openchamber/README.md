# openchamber

Image for [OpenChamber](https://github.com/openchamber/openchamber), a web UI for the [OpenCode](https://opencode.ai) AI agent. Adds an `aqua`-managed CLI toolchain and a `docker buildx` remote-builder client so an OpenCode session can lazy-install ~2000 CLI tools on demand and build container images against an external rootless BuildKit without `--privileged` or a docker socket.

## Composition

Multi-stage build over upstream source:

- `source` stage: clones `openchamber/openchamber.git` at the pinned `OPENCHAMBER_VERSION` ref.
- `deps` stage: `bun install --frozen-lockfile --ignore-scripts` against the workspace `package.json` set, matching upstream.
- `builder` stage: `bun run build:web` to produce the web bundle.
- runtime stage: `oven/bun:1.3.14-slim` with a minimal apt set, `aqua` and `aqua-registry` pulled in from dedicated build stages (alpine-based, native `ADD` for the registry), docker CLI and buildx plugin from `docker:<version>-cli`, cloudflared digest-pinned, opencode-ai installed via `npm install --global`.

Four Renovate-tracked pins:

- `OPENCHAMBER_VERSION` — upstream source ref (github-releases datasource).
- `AQUA_VERSION` — aqua binary release (github-releases datasource).
- `AQUA_REGISTRY_VERSION` — aqua-registry release providing the global package catalog (github-releases datasource).
- `OPENCODE_AI_VERSION` — opencode-ai npm package installed globally (npm datasource).

## What ships at runtime

- The OpenChamber web server bound at `:3000`.
- `aqua` with the standard registry pre-linked (~2000 CLI tools lazy-installed on first invocation). No per-project `aqua.yaml` required for any tool the standard registry covers.
- `docker` CLI + `docker buildx` plugin. Daemon is external — see the BuildKit section.
- `cloudflared` for tunnel modes (matches upstream).
- `opencode-ai` installed globally so OpenChamber can spawn opencode sessions out of the box.

## Running

### Without the BuildKit remote builder

The image works as a plain OpenChamber server when `BUILDKIT_HOST` is unset.

```yaml
services:
  openchamber:
    image: ghcr.io/0xd9c706e8/openchamber:1
    ports:
      - '3000:3000'
    environment:
      OPENCHAMBER_UI_PASSWORD: ${OPENCHAMBER_UI_PASSWORD:?Set before exposing}
    volumes:
      - ./data/openchamber:/home/openchamber/.config/openchamber
      - ./data/opencode/share:/home/openchamber/.local/share/opencode
      - ./data/opencode/state:/home/openchamber/.local/state/opencode
      - ./data/opencode/config:/home/openchamber/.config/opencode
      - ./data/ssh:/home/openchamber/.ssh
      - ./data/aqua:/home/openchamber/.local/share/aquaproj-aqua
      - ./workspaces:/home/openchamber/workspaces
```

### With the BuildKit remote builder (mTLS)

Set `BUILDKIT_HOST` and mount the mTLS material at `/certs/`. The entrypoint provisions a `buildx` remote builder named `remote` on first start.

```yaml
services:
  openchamber:
    image: ghcr.io/0xd9c706e8/openchamber:1
    ports:
      - '3000:3000'
    environment:
      OPENCHAMBER_UI_PASSWORD: ${OPENCHAMBER_UI_PASSWORD:?Set before exposing}
      BUILDKIT_HOST: tcp://buildkit:1234
    volumes:
      - ./data/openchamber:/home/openchamber/.config/openchamber
      - ./data/opencode/share:/home/openchamber/.local/share/opencode
      - ./data/opencode/state:/home/openchamber/.local/state/opencode
      - ./data/opencode/config:/home/openchamber/.config/opencode
      - ./data/ssh:/home/openchamber/.ssh
      - ./data/aqua:/home/openchamber/.local/share/aquaproj-aqua
      - ./workspaces:/home/openchamber/workspaces
      - ./certs:/certs:ro

  buildkit:
    image: ghcr.io/0xd9c706e8/buildkit:1
    command:
      - --addr=tcp://0.0.0.0:1234
      - --tlscacert=/certs/ca.pem
      - --tlscert=/certs/cert.pem
      - --tlskey=/certs/key.pem
    volumes:
      - buildkit-cache:/home/user/.local/share/buildkit
      - ./certs-server:/certs:ro

volumes:
  buildkit-cache:
```

Inside an OpenChamber session, the agent's bash tool can run `docker buildx build --builder remote ...` against the remote daemon.

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openchamber
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openchamber
  template:
    metadata:
      labels:
        app: openchamber
    spec:
      containers:
        - name: openchamber
          image: ghcr.io/0xd9c706e8/openchamber:1
          ports:
            - containerPort: 3000
          env:
            - name: OPENCHAMBER_UI_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: openchamber
                  key: ui-password
            - name: BUILDKIT_HOST
              value: tcp://buildkit:1234
          volumeMounts:
            - name: openchamber-config
              mountPath: /home/openchamber/.config/openchamber
            - name: opencode-share
              mountPath: /home/openchamber/.local/share/opencode
            - name: opencode-state
              mountPath: /home/openchamber/.local/state/opencode
            - name: opencode-config
              mountPath: /home/openchamber/.config/opencode
            - name: aqua-cache
              mountPath: /home/openchamber/.local/share/aquaproj-aqua
            - name: workspaces
              mountPath: /home/openchamber/workspaces
            - name: certs
              mountPath: /certs
              readOnly: true
            - name: ssh
              mountPath: /home/openchamber/.ssh
      volumes:
        - name: certs
          secret:
            secretName: openchamber-buildkit-client-tls
        # Persistent volumes for the rest are deployment-shaped (PVC vs hostPath)
```

## Volumes

| Path                                           | Use                                                               |
| ---------------------------------------------- | ----------------------------------------------------------------- |
| `/home/openchamber/.config/openchamber`        | OpenChamber server config + sessions                              |
| `/home/openchamber/.local/share/opencode`      | OpenCode shared state (mandatory)                                 |
| `/home/openchamber/.local/state/opencode`      | OpenCode local state                                              |
| `/home/openchamber/.config/opencode`           | OpenCode config                                                   |
| `/home/openchamber/.ssh`                       | SSH keys for git operations                                       |
| `/home/openchamber/.local/share/aquaproj-aqua` | aqua tool cache (lazy-installed CLI binaries)                     |
| `/home/openchamber/workspaces`                 | Project worktrees                                                 |
| `/certs` (read-only, optional)                 | mTLS material for the BuildKit remote builder (`ca/cert/key.pem`) |

## Ports

| Port     | Service            |
| -------- | ------------------ |
| 3000/tcp | OpenChamber web UI |

## Environment

| Variable                                     | Effect                                                                                                                              |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `OPENCHAMBER_UI_PASSWORD`                    | Required when exposing the server beyond localhost. Upstream contract.                                                              |
| `BUILDKIT_HOST`                              | When set with `/certs/{ca,cert,key}.pem` mounted, the entrypoint provisions a `buildx` remote builder pointing here.                |
| `OPENCODE_HOST`, `OPENCODE_SKIP_START`, etc. | Upstream OpenChamber env. See [openchamber/openchamber#readme](https://github.com/openchamber/openchamber#readme) for the full set. |

## Security

- Runs as UID/GID 1000:1000 (`openchamber`).
- Cert material at `/certs/` is read-only and copied into `~/.docker/buildx/certs/remote/` with `0644`/`0600` permissions on entrypoint.
- The entrypoint is a no-op when `BUILDKIT_HOST` is unset; image works without the remote builder for non-build sessions.

## Dev toolchains via aqua

The image ships [aqua](https://aquaproj.github.io) wired against the [aqua-registry](https://github.com/aquaproj/aqua-registry) standard catalog. At build time, `aqua install --only-link --all` pre-creates hardlinks for every package the registry covers (~2000 CLI tools). At runtime, the first invocation of any tool downloads the registry's pinned version on demand (lazy install).

What this means in practice for an OpenCode session:

- `node`, `go`, `uv`, `rustup-init`, `terraform`, `kubectl`, `helm`, `gh`, `jq`, `yq`, and ~2000 other CLI tools resolve cleanly without any per-project config.
- Python is installed via `uv` (e.g. `uv python install 3.13` or `uv run python script.py`). The image does not ship a system Python.
- Rust is bootstrapped on first use via `rustup-init -y --no-modify-path && source ~/.cargo/env`.
- `AQUA_DISABLE_POLICY=true` is set so lazy installs don't require interactive policy approval.

The aqua cache at `/home/openchamber/.local/share/aquaproj-aqua` should be a persistent volume — without it, every restart re-downloads installed binaries. PATH order puts `~/.npm-global/bin` before aqua's bin dir, so the npm-installed `opencode-ai@${OPENCODE_AI_VERSION}` wins over aqua's `anomalyco/opencode` hardlink; that's the version that actually runs.

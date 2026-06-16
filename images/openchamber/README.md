# openchamber

Image for [OpenChamber](https://github.com/btriapitsyn/openchamber), a web UI for the [OpenCode](https://opencode.ai) AI agent. Adds a `mise`-driven dev toolchain and a `docker buildx` remote-builder client so an OpenCode session can install per-project language runtimes on demand and build container images against an external rootless BuildKit without `--privileged` or a docker socket.

## Composition

Multi-stage build over upstream source:

- `source` stage: clones `btriapitsyn/openchamber.git` at the pinned `OPENCHAMBER_VERSION` ref.
- `deps` stage: `bun install --frozen-lockfile --ignore-scripts` against the workspace `package.json` set, matching upstream.
- `builder` stage: `bun run build:web` to produce the web bundle.
- runtime stage: `oven/bun:1.3.5` with the upstream apt set, mise extracted from its GitHub release tarball, docker CLI and buildx plugin from `docker:<version>-cli`, cloudflared digest-pinned, opencode-ai installed via `npm install -g`.

Four Renovate-tracked pins:

- `OPENCHAMBER_VERSION` — upstream source ref (github-releases datasource).
- `MISE_VERSION` — mise release tarball (github-releases datasource).
- `DOCKER_VERSION` — docker CLI source stage (docker datasource).
- `OPENCODE_AI_VERSION` — opencode-ai npm package installed globally (npm datasource).

## What ships at runtime

- The OpenChamber web server bound at `:3000`.
- `mise` for per-project toolchain resolution (`.mise.toml`, `.tool-versions`, `.nvmrc`, `.python-version`).
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
      - ./data/mise:/home/openchamber/.local/share/mise
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
      - ./data/mise:/home/openchamber/.local/share/mise
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
            - name: mise-cache
              mountPath: /home/openchamber/.local/share/mise
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

| Path                                      | Use                                                               |
| ----------------------------------------- | ----------------------------------------------------------------- |
| `/home/openchamber/.config/openchamber`   | OpenChamber server config + sessions                              |
| `/home/openchamber/.local/share/opencode` | OpenCode shared state (mandatory)                                 |
| `/home/openchamber/.local/state/opencode` | OpenCode local state                                              |
| `/home/openchamber/.config/opencode`      | OpenCode config                                                   |
| `/home/openchamber/.ssh`                  | SSH keys for git operations                                       |
| `/home/openchamber/.local/share/mise`     | mise toolchain cache                                              |
| `/home/openchamber/workspaces`            | Project worktrees                                                 |
| `/certs` (read-only, optional)            | mTLS material for the BuildKit remote builder (`ca/cert/key.pem`) |

## Ports

| Port     | Service            |
| -------- | ------------------ |
| 3000/tcp | OpenChamber web UI |

## Environment

| Variable                                     | Effect                                                                                                                              |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `OPENCHAMBER_UI_PASSWORD`                    | Required when exposing the server beyond localhost. Upstream contract.                                                              |
| `BUILDKIT_HOST`                              | When set with `/certs/{ca,cert,key}.pem` mounted, the entrypoint provisions a `buildx` remote builder pointing here.                |
| `OPENCODE_HOST`, `OPENCODE_SKIP_START`, etc. | Upstream OpenChamber env. See [openchamber/openchamber#readme](https://github.com/btriapitsyn/openchamber#readme) for the full set. |

## Security

- Runs as UID/GID 1000:1000 (`openchamber`).
- Cert material at `/certs/` is read-only and copied into `~/.docker/buildx/certs/remote/` with `0644`/`0600` permissions on entrypoint.
- The entrypoint is a no-op when `BUILDKIT_HOST` is unset; image works without the remote builder for non-build sessions.

## Dev toolchains via mise

Per-project `.mise.toml` resolves Node, Python, Go, Rust, Bun, Terraform, kubectl, helm, and ~500 other tools on demand. The mise data dir at `/home/openchamber/.local/share/mise` should be a persistent volume — without it, every restart re-downloads installed toolchains.

Toolchains are resolved at session-bash-tool invocation time, not at image-build time. The image only pins `mise` itself; everything else is the user's project responsibility.

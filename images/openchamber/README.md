# openchamber

Image for [OpenChamber](https://github.com/openchamber/openchamber), a web UI for the [OpenCode](https://opencode.ai) AI agent. This image contains only the OpenChamber web server; it expects an external OpenCode server reachable via `OPENCODE_HOST`.

For the matching OpenCode runtime image — with the `aqua`-managed CLI toolchain, `docker buildx` remote-builder client, and `opencode serve` — see [`images/opencode`](../opencode).

## Composition

Multi-stage build over upstream source:

- `source` stage: clones `openchamber/openchamber.git` at the pinned `OPENCHAMBER_VERSION` ref.
- `deps` stage: `bun install --frozen-lockfile --ignore-scripts` against the workspace `package.json` set, matching upstream.
- `builder` stage: `bun run build:web` to produce the web bundle.
- `runtime` stage: `node:24-trixie-slim` with the built web assets and git/openssh-client. Build stages still use `oven/bun:1.3.14-slim` to consume the upstream `bun.lock` lockfile.

One Renovate-tracked pin:

- `OPENCHAMBER_VERSION` — upstream source ref (github-releases datasource).

## What ships at runtime

- The OpenChamber web server bound at `:3000`.
- `OPENCODE_SKIP_START=true` is baked in so OpenChamber never tries to start a bundled OpenCode server.

## Running

### With the OpenCode runtime image

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

  openchamber:
    image: ghcr.io/0xd9c706e8/openchamber:1
    ports:
      - '3000:3000'
    environment:
      OPENCHAMBER_UI_PASSWORD: ${OPENCHAMBER_UI_PASSWORD:?Set before exposing}
      OPENCODE_HOST: http://opencode:4096
    volumes:
      - ./data/openchamber:/home/openchamber/.config/openchamber
      - ./data/ssh:/home/openchamber/.ssh
```

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
            - name: OPENCODE_HOST
              value: http://opencode:4096
          volumeMounts:
            - name: openchamber-config
              mountPath: /home/openchamber/.config/openchamber
            - name: ssh
              mountPath: /home/openchamber/.ssh
      volumes:
        # Persistent volumes are deployment-shaped (PVC vs hostPath)
```

## Volumes

| Path                                    | Use                                  |
| --------------------------------------- | ------------------------------------ |
| `/home/openchamber/.config/openchamber` | OpenChamber server config + sessions |
| `/home/openchamber/.ssh`                | SSH keys for git operations          |

## Ports

| Port     | Service            |
| -------- | ------------------ |
| 3000/tcp | OpenChamber web UI |

## Environment

| Variable                  | Effect                                                                                                                    |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `OPENCHAMBER_UI_PASSWORD` | Required when exposing the server beyond localhost. Upstream contract.                                                    |
| `OPENCODE_HOST`           | Required. URL of the external OpenCode server, e.g. `http://opencode:4096`. See OpenChamber docs for format requirements. |
| `OPENCODE_SKIP_START`     | Defaults to `true` in the image. Prevents OpenChamber from starting its own OpenCode server.                              |

## Security

- Runs as UID/GID 1000:1000 (`openchamber`).
- SSH private key is generated on first start if missing and stored under `/home/openchamber/.ssh`.

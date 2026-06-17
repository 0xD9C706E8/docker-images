# buildkit

Rootless image for [BuildKit](https://github.com/moby/buildkit), the build subsystem behind `docker buildx`. Meant to back a remote-builder topology where a separate container drives `buildkitd` over TCP, so the consuming workload (CI, dev shell, agent) never needs `--privileged` or a docker socket.

## Build composition

Four Go binaries are built from upstream source per release:

- `buildkitd` — the daemon (CGO disabled, static)
- `buildctl` — the gRPC client (CGO disabled, static)
- `rootlesskit` — the user-namespace wrapper (CGO disabled, static)
- `runc` — the OCI runtime that actually executes build steps (CGO enabled, libseccomp statically linked, matches upstream `moby/buildkit:rootless` for seccomp coverage)

Final stage is `alpine:3.24` with `fuse-overlayfs`, `fuse3`, `git`, `openssh-client`, `pigz`, `shadow-subids`, `shadow-uidmap`, `xz`. `newuidmap`/`newgidmap` carry `cap_setuid=ep` / `cap_setgid=ep` file capabilities (applied with `libcap-utils`, installed and removed in the same layer) — file caps round-trip through OCI cleanly; the setuid bit does not. Smaller runtime surface than upstream's rootless variant: drops the openssh server (we only ever invoke ssh as a client) and drops `openssl` (only used in vendored test code, never at runtime).

## Running

The image expects to be driven by an external client over TCP. mTLS is the recommended trust boundary on any non-loopback network.

### docker compose

```yaml
services:
  buildkit:
    image: ghcr.io/0xd9c706e8/buildkit:1
    command:
      - --addr=tcp://0.0.0.0:1234
      - --tlscacert=/certs/ca.pem
      - --tlscert=/certs/cert.pem
      - --tlskey=/certs/key.pem
    volumes:
      - buildkit-cache:/home/user/.local/share/buildkit
      - ./certs:/certs:ro
    ports:
      - '1234:1234'

volumes:
  buildkit-cache:
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: buildkit
spec:
  serviceName: buildkit
  replicas: 1
  selector:
    matchLabels:
      app: buildkit
  template:
    metadata:
      labels:
        app: buildkit
    spec:
      containers:
        - name: buildkitd
          image: ghcr.io/0xd9c706e8/buildkit:1
          args:
            - --addr=tcp://0.0.0.0:1234
            - --tlscacert=/certs/ca.pem
            - --tlscert=/certs/cert.pem
            - --tlskey=/certs/key.pem
          ports:
            - containerPort: 1234
          volumeMounts:
            - name: cache
              mountPath: /home/user/.local/share/buildkit
            - name: certs
              mountPath: /certs
              readOnly: true
      volumes:
        - name: certs
          secret:
            secretName: buildkit-tls
  volumeClaimTemplates:
    - metadata:
        name: cache
      spec:
        accessModes: ['ReadWriteOnce']
        resources:
          requests:
            storage: 50Gi
```

## Volumes

| Path                               | Use                                                                        |
| ---------------------------------- | -------------------------------------------------------------------------- |
| `/home/user/.local/share/buildkit` | Build cache. Persist this or every restart re-downloads layers.            |
| `/certs`                           | mTLS material (`ca.pem`, `cert.pem`, `key.pem`). Read-only, secret-backed. |

The cache path matches upstream `moby/buildkit:<version>-rootless`.

## Ports

| Port     | Service                                                 |
| -------- | ------------------------------------------------------- |
| 1234/tcp | BuildKit gRPC API (mTLS-only when `--tlscacert` is set) |

`EXPOSE 1234` is documentation; the daemon defaults to a unix socket and only switches to TCP when `--addr=tcp://...` is passed.

## Security

- Runs as UID/GID 1000:1000.
- subuid/subgid range `100000:65536` is provisioned at build time for `rootlesskit` user-namespace mapping.
- mTLS is the recommended trust boundary between client and daemon — pass `--tlscacert`, `--tlscert`, `--tlskey` at the runtime layer.
- Unauthenticated TCP exposure is supported by upstream but not recommended on shared networks.

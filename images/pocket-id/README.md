# pocket-id

Rootless image for [Pocket-ID](https://github.com/pocket-id/pocket-id), a passkey-first OIDC provider.

## Configuration

Pocket-ID is configured entirely through environment variables. `APP_URL` and `ENCRYPTION_KEY` are the only required ones. See the [environment variables reference](https://pocket-id.org/docs/configuration/environment-variables) for the full schema.

| Variable               | Required | Notes                                                                 |
| ---------------------- | -------- | --------------------------------------------------------------------- |
| `APP_URL`              | yes      | Public URL the frontend is reached on, e.g. `https://id.example.com`  |
| `ENCRYPTION_KEY`       | yes      | At least 16 bytes; generate with `openssl rand -base64 32`            |
| `DB_CONNECTION_STRING` | no       | Postgres DSN. Defaults to SQLite at `/app/data/pocket-id.db`          |
| `PORT`                 | no       | Override the listen port. Defaults to `1411`                          |
| `TRUST_PROXY`          | no       | Set to `true` when sitting behind a reverse proxy that terminates TLS |
| `MAXMIND_LICENSE_KEY`  | no       | Enables GeoLite2 lookups for audit log enrichment                     |

`ENCRYPTION_KEY_FILE` is also honored if you prefer mounting the key as a file (Docker secrets / K8s `Secret` volumeMounts).

## Volumes

| Path        | Use                                                  |
| ----------- | ---------------------------------------------------- |
| `/app/data` | SQLite DB + uploaded assets (profile pictures, etc.) |

The `/app/data` mount must be writable by UID/GID 65532:65532 (the distroless `nonroot` user). Skip the volume when running against Postgres via `DB_CONNECTION_STRING`.

## Ports

| Port     | Service                       |
| -------- | ----------------------------- |
| 1411/tcp | HTTP API + admin web UI + SPA |

Pocket-ID serves both the API and the embedded SvelteKit frontend on the same port. Terminate TLS at the reverse proxy.

## Healthcheck

The image declares a Docker `HEALTHCHECK` that runs `pocket-id healthcheck` every 90 seconds. The probe hits `/healthz` on the local listener, so it only goes green once the HTTP server is up.

K8s ignores Docker `HEALTHCHECK` directives; for K8s deployments wire your own `livenessProbe` / `readinessProbe`:

```yaml
livenessProbe:
  exec:
    command: ['/usr/local/bin/pocket-id', 'healthcheck']
  initialDelaySeconds: 10
  periodSeconds: 60
```

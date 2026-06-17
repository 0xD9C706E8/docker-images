# tinyauth

Rootless image for [tinyauth](https://github.com/tinyauthapp/tinyauth), a forward-auth and OIDC gateway for reverse proxies like Traefik, Caddy, and nginx.

## Configuration

tinyauth reads config exclusively from environment variables in the `TINYAUTH_<SECTION>_<KEY>` shape. The full reference lives in the upstream [.env.example](https://github.com/tinyauthapp/tinyauth/blob/main/.env.example). The bare-minimum set:

| Variable              | Purpose                                                             |
| --------------------- | ------------------------------------------------------------------- |
| `TINYAUTH_APPURL`     | Public URL the gateway is reachable at, e.g. `https://auth.example` |
| `TINYAUTH_AUTH_USERS` | Bcrypt-hashed user list, e.g. `alice:$2a$10$...,bob:$2a$10$...`     |

## Volumes

tinyauth persists session state and custom assets:

| Path                | Use                                                           |
| ------------------- | ------------------------------------------------------------- |
| `/data/tinyauth.db` | SQLite database (default) — set via `TINYAUTH_DATABASE_PATH`  |
| `/data/resources`   | Optional custom UI assets — set via `TINYAUTH_RESOURCES_PATH` |

Mount `/data` as a PVC in K8s or a named volume in Docker. Use `TINYAUTH_DATABASE_DRIVER=memory` for a stateless deployment that resets every restart.

## Ports

| Port     | Service             |
| -------- | ------------------- |
| 3000/tcp | HTTP + forward-auth |

## Healthcheck

The image declares a Docker `HEALTHCHECK` that runs `tinyauth healthcheck` every 30 seconds. K8s ignores Docker `HEALTHCHECK` directives; for K8s deployments wire your own `livenessProbe` / `readinessProbe`:

```yaml
livenessProbe:
  exec:
    command: ['/usr/local/bin/tinyauth', 'healthcheck']
  initialDelaySeconds: 5
  periodSeconds: 30
```

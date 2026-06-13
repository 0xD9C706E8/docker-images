# lldap

Rootless image for [LLDAP](https://github.com/lldap/lldap), a light LDAP server with a web UI, backed by SQLite, MariaDB, or Postgres.

## Configuration

LLDAP reads its config from `/data/lldap_config.toml`. The image does **not** auto-seed a default config; place a real `lldap_config.toml` at `/data/lldap_config.toml` before first boot.

A reference template ships at `/app/lldap_config.docker_template.toml`. Copy it once and edit:

```bash
docker run --rm ghcr.io/0xd9c706e8/lldap \
  cat /app/lldap_config.docker_template.toml > lldap_config.toml
```

Required fields to change before going to prod: `jwt_secret`, `key_seed`, `ldap_user_pass`. See the [LLDAP config reference](https://github.com/lldap/lldap/blob/main/lldap_config.docker_template.toml) for the full schema.

## Volumes

| Path    | Use                                                |
| ------- | -------------------------------------------------- |
| `/data` | Config (`lldap_config.toml`) + SQLite DB + secrets |

The `/data` mount must be writable by UID/GID 1000:1000.

## Ports

| Port      | Service                 |
| --------- | ----------------------- |
| 3890/tcp  | LDAP                    |
| 17170/tcp | HTTP API + admin web UI |

LDAPS isn't enabled by default. Terminate TLS at the reverse proxy, or configure it in `lldap_config.toml`.

## Healthcheck

The image declares a Docker `HEALTHCHECK` that runs `lldap healthcheck --config-file /data/lldap_config.toml`. It pings the HTTP and LDAP ports against the local instance, so it only goes green once both listeners are up.

K8s ignores Docker `HEALTHCHECK` directives; for K8s deployments wire your own `livenessProbe` / `readinessProbe`:

```yaml
livenessProbe:
  exec:
    command:
      ['/app/lldap', 'healthcheck', '--config-file', '/data/lldap_config.toml']
  initialDelaySeconds: 10
  periodSeconds: 60
```

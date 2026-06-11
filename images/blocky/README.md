# blocky

Rootless image for [Blocky](https://github.com/0xERR0R/blocky), a DNS proxy and ad-blocker for the home network.

## Networking

Blocky binds DNS on UDP/53 + TCP/53. Port 53 is below 1024, so the nonroot user needs `CAP_NET_BIND_SERVICE` to bind it. Grant the capability at the runtime level.

Docker:

```bash
docker run --cap-add NET_BIND_SERVICE ghcr.io/0xd9c706e8/blocky
```

K8s:

```yaml
securityContext:
  capabilities:
    add: ['NET_BIND_SERVICE']
```

## Configuration

Blocky reads its config from `/app/config.yml` by default via `BLOCKY_CONFIG_FILE`. Mount your `config.yml` there, or set `BLOCKY_CONFIG_FILE` to a different path. See the [Blocky config reference](https://0xerr0r.github.io/blocky/latest/configuration/) for the full schema.

## Volumes

Blocky is stateless by default. Optional persistence:

| Path              | Use                                                       |
| ----------------- | --------------------------------------------------------- |
| `/app/config.yml` | Mounted config file (read-only)                           |
| `/app/data`       | Optional, only when `queryLog.type: sqlite` is configured |

## Ports

| Port            | Service                       |
| --------------- | ----------------------------- |
| 53/udp + 53/tcp | DNS                           |
| 4000/tcp        | REST API + Prometheus metrics |

DoT (853), DoH (443), and DoQ (853) are configurable but not exposed by default. Add them to your config + Service if you need them.

## Healthcheck

The image declares a Docker `HEALTHCHECK` that runs `blocky healthcheck` every minute. It queries `healthcheck.blocky.` against localhost:53, so it only goes green once the DNS listener is up. The probe assumes Blocky's default bind address and port; if you change them in your config, pass `--bindip` / `--port` to `blocky healthcheck` to match.

K8s ignores Docker `HEALTHCHECK` directives; for K8s deployments wire your own `livenessProbe` / `readinessProbe` instead. The same subcommand works there:

```yaml
livenessProbe:
  exec:
    command: ['/usr/local/bin/blocky', 'healthcheck']
  initialDelaySeconds: 10
  periodSeconds: 60
```

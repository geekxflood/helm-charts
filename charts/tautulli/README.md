# Tautulli Helm Chart

![Version: 0.3.1](https://img.shields.io/badge/Version-0.3.1-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 2.17.1](https://img.shields.io/badge/AppVersion-2.17.1-informational?style=flat-square)

A Helm chart for deploying [Tautulli](https://tautulli.com/) — a Python-based monitoring and analytics tool for [Plex Media Server](https://www.plex.tv/). Tautulli tracks watch history, generates statistics on libraries and users, sends notifications (Discord, email, webhooks), and exposes a rich web UI plus a JSON API consumed by tools like [tautulli-exporter](../tautulli-exporter).

This chart deploys the [LinuxServer.io Tautulli image](https://hub.docker.com/r/linuxserver/tautulli) as a single-replica `Deployment`.

## Features

- Single-replica `Deployment` of `linuxserver/tautulli`
- Standard `Service` (`ClusterIP` by default) on port `8181`
- Ingress and Gateway API `HTTPRoute` (Cilium / Istio / Envoy Gateway compatible)
- Optional Cloudflare Tunnel binding (`cfTunnel`) for exposure without inbound ingress
- `envFrom` support for `secret` / `configmap` references (e.g. inject `TAUTULLI__API_KEY` from a Secret)
- Configurable container `runtimeClassName` (e.g. `gVisor`, `kata`)
- HPA configuration kept for parity with sibling charts (note: Tautulli has local SQLite state — keep replicas at 1)
- `volumes` / `volumeMounts` passthrough for the `/config` directory PVC

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- A reachable Plex Media Server (in-cluster or external)
- Persistent storage for `/config` (SQLite database, notification history, settings) — provided via `volumes` / `volumeMounts`
- For ingress: an ingress controller; for `httpRoute`: Gateway API CRDs and a Gateway
- For `cfTunnel`: a Cloudflare Tunnel operator that consumes `TunnelBinding` resources

## Installation

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm install tautulli geekxflood/tautulli
helm install tautulli geekxflood/tautulli -f values.yaml
```

The default `enabled: false` is a deliberate guard — set `enabled: true` to actually render workload resources.

## Configuration

### Workload

| Parameter                                | Description                                                          | Default                |
| ---------------------------------------- | -------------------------------------------------------------------- | ---------------------- |
| `enabled`                                | Render the chart workload                                            | `false`                |
| `replicaCount`                           | Replica count (keep at 1 unless using `ReadWriteMany` config volume) | `1`                    |
| `image.repository`                       | Image                                                                | `linuxserver/tautulli` |
| `image.tag`                              | Image tag                                                            | `2.17.1`               |
| `image.pullPolicy`                       | Image pull policy                                                    | `IfNotPresent`         |
| `imagePullSecrets`                       | Image pull secrets                                                   | `[]`                   |
| `nameOverride` / `fullnameOverride`      | Naming overrides                                                     | `""`                   |
| `podAnnotations` / `podLabels`           | Pod metadata                                                         | `{}`                   |
| `podSecurityContext` / `securityContext` | Pod / container security contexts                                    | `{}`                   |
| `resources`                              | Pod resources                                                        | `{}`                   |
| `runtime.enabled` / `runtime.name`       | Custom `runtimeClassName`                                            | `false` / `""`         |

### Environment & secrets

| Parameter | Description                                       | Default |
| --------- | ------------------------------------------------- | ------- |
| `env`     | Raw env vars (`[{name, value}]`)                  | `[]`    |
| `envFrom` | List of `{type: secret\|configmap, name: <name>}` | `[]`    |

LinuxServer images conventionally accept `PUID`, `PGID`, `TZ`. Set Tautulli configuration via `env` or via persistent `/config/config.ini`.

### Service & exposure

| Parameter                                             | Description                                | Default           |
| ----------------------------------------------------- | ------------------------------------------ | ----------------- |
| `service.type`                                        | Service type                               | `ClusterIP`       |
| `service.port`                                        | Service port                               | `8181`            |
| `ingress.enabled`                                     | Enable Ingress                             | `false`           |
| `ingress.className` / `annotations` / `hosts` / `tls` | Standard ingress wiring                    | see `values.yaml` |
| `httpRoute.enabled`                                   | Enable Gateway API HTTPRoute               | `false`           |
| `httpRoute.parentRefs` / `hostnames` / `rules`        | Standard HTTPRoute wiring                  | `[]`              |
| `cfTunnel.enabled`                                    | Render a Cloudflare Tunnel `TunnelBinding` | `false`           |
| `cfTunnel.tunnelRef` / `cfTunnel.subjects`            | Tunnel target / subjects                   | `{}`              |

### Storage

| Parameter      | Description                          | Default |
| -------------- | ------------------------------------ | ------- |
| `volumes`      | Pod volumes (e.g. PVC for `/config`) | `[]`    |
| `volumeMounts` | Container mounts                     | `[]`    |

### Scheduling & autoscaling

| Parameter                                    | Description                                  | Default            |
| -------------------------------------------- | -------------------------------------------- | ------------------ |
| `nodeSelector` / `tolerations` / `affinity`  | Standard scheduling                          | `{}` / `[]` / `{}` |
| `autoscaling.enabled`                        | Enable HPA (keep off — single SQLite writer) | `false`            |
| `autoscaling.minReplicas` / `maxReplicas`    | HPA bounds                                   | `1` / `100`        |
| `autoscaling.targetCPUUtilizationPercentage` | CPU target                                   | `80`               |

## Examples

### Single-instance install with PVC and Ingress

```yaml
enabled: true

env:
  - { name: PUID, value: "1000" }
  - { name: PGID, value: "1000" }
  - { name: TZ, value: "Europe/Berlin" }

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
  hosts:
    - host: tautulli.example.com
      paths:
        - { path: /, pathType: Prefix }
  tls:
    - secretName: tautulli-tls
      hosts: [tautulli.example.com]

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: tautulli-config

volumeMounts:
  - name: config
    mountPath: /config
```

### Behind Gateway API + Tautulli API key from a Secret

```yaml
enabled: true

env:
  - { name: PUID, value: "1000" }
  - { name: PGID, value: "1000" }
  - { name: TZ, value: "UTC" }

envFrom:
  - { type: secret, name: tautulli-api-key }

httpRoute:
  enabled: true
  parentRefs:
    - { name: cilium-gateway, namespace: gateway-system, sectionName: https }
  hostnames: [tautulli.example.com]
  rules:
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs: [{}]

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: tautulli-config
volumeMounts:
  - name: config
    mountPath: /config
```

## Persistence

Tautulli stores its **SQLite database**, **session history**, **notifier configuration**, and **API key** under `/config`. Loss of this volume loses all history — back it up. The chart does not create a PVC for you; provide one via `volumes` / `volumeMounts`. Use `ReadWriteOnce` storage and keep `replicaCount: 1` — SQLite does not tolerate concurrent writers.

## Integration notes

- **Plex connection** is configured at first run via the Tautulli web UI under _Settings → Plex Media Server_. Tautulli polls Plex on a schedule and via webhooks.
- **API key**: Tautulli generates one in _Settings → Web Interface → API_. Consumers (notably [tautulli-exporter](../tautulli-exporter)) need it. Store it in a Kubernetes Secret and inject it via `envFrom` or directly into the consumer chart.
- **Metrics**: Tautulli has no native Prometheus endpoint. Pair this chart with [tautulli-exporter](../tautulli-exporter) which queries Tautulli's JSON API and exposes Prometheus metrics.
- **Notifications**: Discord, email, webhooks, etc., are configured inside Tautulli's UI — Kubernetes-level secrets are not required, but if you want to inject webhook URLs, mount them into `/config` files or set via the API.

## Upgrading

- LinuxServer image upgrades are usually drop-in. After bumping `image.tag`, restart the pod; Tautulli migrates its SQLite schema on first start.
- Always have a `/config` backup before crossing major Tautulli versions (e.g. 2.x).

## Support

- Tautulli: <https://tautulli.com/> · <https://github.com/Tautulli/Tautulli>
- LinuxServer image: <https://docs.linuxserver.io/images/docker-tautulli/>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

- Chart: Apache License 2.0
- Tautulli: [GPL-3.0](https://github.com/Tautulli/Tautulli/blob/master/LICENSE)

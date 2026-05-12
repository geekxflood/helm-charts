# Tautulli Exporter Helm Chart

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: v0.1.0](https://img.shields.io/badge/AppVersion-v0.1.0-informational?style=flat-square)

A Helm chart that deploys [tautulli_exporter](https://github.com/nwalke/tautulli_exporter) — a Prometheus exporter that polls the [Tautulli](../tautulli) JSON API and exposes Plex watch-time, stream count, library size, and user activity metrics on `:9487/metrics`.

This is the metrics half of the Plex monitoring stack: pair it with the [Tautulli](../tautulli) chart and a Prometheus deployment to graph Plex activity in Grafana.

## Features

- Single-replica `Deployment` of `nwalke/tautulli_exporter`
- Service on port `9487` named `http` (consumed by the optional `ServiceMonitor`)
- Optional `ServiceMonitor` for the Prometheus Operator
- Ingress and Gateway API `HTTPRoute` exposure (rarely needed — metrics endpoints stay internal)
- Optional Cloudflare Tunnel `TunnelBinding` (mostly for debugging)
- `env` / `envFrom` injection for the Tautulli URL and API key
- HPA fields kept for parity (the exporter is effectively stateless and CPU-cheap)

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- A running [Tautulli](../tautulli) instance reachable from this pod (typically via in-cluster Service DNS)
- A **Tautulli API key** (Tautulli → Settings → Web Interface → API) — supplied via `env` or `envFrom`
- For `ServiceMonitor`: the Prometheus Operator and a Prometheus instance configured to discover ServiceMonitors with the relevant label selector

## Installation

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm install tautulli-exporter geekxflood/tautulli-exporter
helm install tautulli-exporter geekxflood/tautulli-exporter -f values.yaml
```

The default `enabled: false` is a guard — set `enabled: true` for resources to render.

## Configuration

### Workload

| Parameter                                | Description                       | Default                    |
| ---------------------------------------- | --------------------------------- | -------------------------- |
| `enabled`                                | Render workload resources         | `false`                    |
| `replicaCount`                           | Replica count                     | `1`                        |
| `image.repository`                       | Image                             | `nwalke/tautulli_exporter` |
| `image.tag`                              | Image tag                         | `v0.1.0`                   |
| `image.pullPolicy`                       | Pull policy                       | `IfNotPresent`             |
| `imagePullSecrets`                       | Image pull secrets                | `[]`                       |
| `podAnnotations` / `podLabels`           | Pod metadata                      | `{}`                       |
| `podSecurityContext` / `securityContext` | Pod / container security contexts | `{}`                       |
| `resources`                              | Pod resources                     | `{}`                       |
| `runtime.enabled` / `runtime.name`       | Custom `runtimeClassName`         | `false` / `""`             |

### Tautulli connection (via env / envFrom)

The exporter binary reads its configuration from environment variables. Inject them via `env` or `envFrom`:

| Variable (upstream) | Purpose                                                                            |
| ------------------- | ---------------------------------------------------------------------------------- |
| `TAUTULLI_URL`      | Base URL of the Tautulli API (e.g. `http://tautulli.media.svc.cluster.local:8181`) |
| `TAUTULLI_API_KEY`  | API key from the Tautulli UI                                                       |

Refer to the [upstream exporter README](https://github.com/nwalke/tautulli_exporter) for the exact env-var names supported by your image tag — the values above are the conventions for `v0.1.0`.

### Service & exposure

| Parameter                                             | Description                         | Default           |
| ----------------------------------------------------- | ----------------------------------- | ----------------- |
| `service.type`                                        | Service type                        | `ClusterIP`       |
| `service.port`                                        | Service port (named `http`)         | `9487`            |
| `ingress.enabled`                                     | Enable Ingress (rare)               | `false`           |
| `ingress.className` / `annotations` / `hosts` / `tls` | Standard ingress wiring             | see `values.yaml` |
| `httpRoute.enabled`                                   | Enable Gateway API HTTPRoute (rare) | `false`           |
| `httpRoute.parentRefs` / `hostnames` / `rules`        | Standard HTTPRoute wiring           | `[]`              |
| `cfTunnel.enabled`                                    | Render `TunnelBinding`              | `false`           |

### Prometheus integration

| Parameter                | Description                                     | Default |
| ------------------------ | ----------------------------------------------- | ------- |
| `serviceMonitor.enabled` | Render a `ServiceMonitor` (Prometheus Operator) | `false` |

The rendered `ServiceMonitor` selects on `name: <fullname>` and scrapes the `http` port. Ensure your Prometheus is configured to discover `ServiceMonitor`s with your release's labels (most kube-prometheus-stack installs accept the chart-default selectors).

### Scheduling

| Parameter                                   | Description         | Default            |
| ------------------------------------------- | ------------------- | ------------------ |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling | `{}` / `[]` / `{}` |
| `autoscaling.enabled`                       | Enable HPA          | `false`            |

## Examples

### Exporter + ServiceMonitor scraped by kube-prometheus-stack

```yaml
enabled: true

env:
  - { name: TAUTULLI_URL, value: "http://tautulli.media.svc.cluster.local:8181" }

envFrom:
  - { type: secret, name: tautulli-api-key }   # must contain TAUTULLI_API_KEY

serviceMonitor:
  enabled: true

resources:
  requests:
    cpu: 20m
    memory: 32Mi
  limits:
    cpu: 100m
    memory: 64Mi
```

Create the API key Secret:

```bash
kubectl -n media create secret generic tautulli-api-key \
  --from-literal=TAUTULLI_API_KEY=<key-from-tautulli-ui>
```

### Static Prometheus scrape (no operator)

If you do not run the Prometheus Operator, leave `serviceMonitor.enabled: false` and configure a static scrape in your Prometheus config:

```yaml
# values.yaml
enabled: true
env:
  - { name: TAUTULLI_URL, value: "http://tautulli.media.svc.cluster.local:8181" }
envFrom:
  - { type: secret, name: tautulli-api-key }
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9487"
  prometheus.io/path: "/metrics"
```

## Persistence

None. The exporter is stateless — it queries Tautulli on each scrape.

## Integration notes

- **Scrape target**: Prometheus (or any compatible collector) hits `:9487/metrics` on this exporter's `Service`. With `serviceMonitor.enabled: true`, the Operator wires that up automatically.
- **Tautulli reachability**: the URL passed via `TAUTULLI_URL` must be reachable from this pod. Cross-namespace works with the FQDN `tautulli.<namespace>.svc.cluster.local`.
- **API key rotation**: regenerate in Tautulli's UI, update the Kubernetes Secret, and restart the exporter pod.
- **Do not expose** the metrics endpoint to the public internet — it leaks Plex usage, library sizes, and user activity. Keep `ingress.enabled` / `httpRoute.enabled` off in production.
- **Dashboards**: community Grafana dashboards for `tautulli_exporter` exist on grafana.com — search "tautulli".

## Upgrading

- The exporter is currently pinned to upstream `v0.1.0`. Bump `image.tag` once newer releases land and verify metric name compatibility against existing dashboards.
- Changing `service.port` is supported but requires updating any consumers (Prometheus scrape config, static dashboards).

## Support

- Upstream: <https://github.com/nwalke/tautulli_exporter>
- Tautulli: <https://tautulli.com/>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

- Chart: Apache License 2.0
- tautulli_exporter: see [upstream LICENSE](https://github.com/nwalke/tautulli_exporter)

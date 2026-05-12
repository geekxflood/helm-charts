# Flaresolverr Helm Chart

![Version: 0.3.0](https://img.shields.io/badge/Version-0.3.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: v3.4.6](https://img.shields.io/badge/AppVersion-v3.4.6-informational?style=flat-square)

A Helm chart for deploying [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr) on Kubernetes. FlareSolverr is a proxy server that bypasses Cloudflare and DDoS-GUARD challenge pages by driving a headless browser (Selenium + undetected-chromedriver). Indexers and metadata tools — most commonly [Prowlarr](https://wiki.servarr.com/prowlarr) and [Jackett](https://github.com/Jackett/Jackett) — point their HTTP traffic at FlareSolverr's `POST /v1` endpoint and get back the solved response.

This chart ships the upstream image `ghcr.io/flaresolverr/flaresolverr`. The service is stateless, has no on-disk config, and is meant to live entirely inside the cluster.

## Features

- Stateless deployment of the official FlareSolverr image with configurable replicas, resources, probes, and pod metadata.
- Configuration entirely through environment variables (`LOG_LEVEL`, `BROWSER_TIMEOUT`, `CAPTCHA_SOLVER`, etc.) via `env` and `envFrom`.
- Pluggable `runtimeClassName` via `runtime.enabled` + `runtime.name` (useful for `gvisor` / `kata` to sandbox the headless browser).
- HTTP service on port 8191 with optional `Ingress`.
- Optional Gateway API `HTTPRoute` for vanilla Kubernetes Gateway implementations.
- Optional Cloudflare Tunnel `TunnelBinding` (rarely needed — FlareSolverr is typically only reachable in-cluster).
- HPA template for horizontal scaling under indexer load.
- Custom `volumes` / `volumeMounts` for advanced cases (mounting Chromium's `/dev/shm` as a larger `emptyDir` is a common one).

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Outbound egress to the public Internet from pods running FlareSolverr (it has to reach the protected target sites).
- ~256 MiB memory minimum per replica; Chromium is the bottleneck. Bump `resources` for sustained workloads.

FlareSolverr does **not** require persistent storage.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install flaresolverr geekxflood/flaresolverr
```

### Install with custom values

```bash
helm install flaresolverr geekxflood/flaresolverr -f values.yaml
```

## Configuration

### Global Parameters

| Parameter      | Description                         | Default |
| -------------- | ----------------------------------- | ------- |
| `enabled`      | Enable/disable the chart deployment | `false` |
| `replicaCount` | Number of FlareSolverr replicas     | `1`     |

### Image Parameters

| Parameter          | Description           | Default                              |
| ------------------ | --------------------- | ------------------------------------ |
| `image.repository` | Image repository      | `ghcr.io/flaresolverr/flaresolverr` |
| `image.pullPolicy` | Image pull policy     | `IfNotPresent`                       |
| `image.tag`        | Image tag             | `"v3.4.6"`                           |
| `imagePullSecrets` | Image pull secrets    | `[]`                                 |

### Service Account Parameters

| Parameter                    | Description                     | Default |
| ---------------------------- | ------------------------------- | ------- |
| `serviceAccount.create`      | Create service account          | `true`  |
| `serviceAccount.automount`   | Automount service account token | `true`  |
| `serviceAccount.annotations` | Service account annotations     | `{}`    |
| `serviceAccount.name`        | Service account name override   | `""`    |

### Pod Parameters

| Parameter            | Description                | Default |
| -------------------- | -------------------------- | ------- |
| `nameOverride`       | Override chart name        | `""`    |
| `fullnameOverride`   | Override full release name | `""`    |
| `podAnnotations`     | Pod annotations            | `{}`    |
| `podLabels`          | Pod labels                 | `{}`    |
| `podSecurityContext` | Pod security context       | `{}`    |
| `securityContext`    | Container security context | `{}`    |

### Runtime Class

| Parameter        | Description                            | Default |
| ---------------- | -------------------------------------- | ------- |
| `runtime.enabled`| Set `runtimeClassName` on the pod      | `false` |
| `runtime.name`   | Runtime class name (e.g., `gvisor`)    | `""`    |

### Environment Variables

| Parameter | Description                                                        | Default |
| --------- | ------------------------------------------------------------------ | ------- |
| `env`     | Literal env vars (`LOG_LEVEL`, `BROWSER_TIMEOUT`, `CAPTCHA_SOLVER`) | `[]`    |
| `envFrom` | Refs to `Secret` / `ConfigMap` by `type` (`secret`\|`configmap`) and `name` | `[]`    |

Common FlareSolverr env vars:

| Variable                 | Description                                                       | Default in image    |
| ------------------------ | ----------------------------------------------------------------- | ------------------- |
| `LOG_LEVEL`              | `debug`, `info`, `warning`, `error`                               | `info`              |
| `LOG_HTML`               | Include rendered HTML in logs (verbose)                           | `false`             |
| `CAPTCHA_SOLVER`         | `none`, `hcaptcha-solver`                                         | `none`              |
| `TZ`                     | Time zone                                                         | `UTC`               |
| `BROWSER_TIMEOUT`        | Per-request browser timeout in ms                                 | `40000`             |
| `TEST_URL`               | Health-check URL hit on startup                                   | `https://www.google.com` |
| `PORT`                   | Listen port inside the container                                  | `8191`              |
| `HOST`                   | Listen address inside the container                               | `0.0.0.0`           |
| `PROMETHEUS_ENABLED`     | Expose Prometheus metrics                                          | `false`             |
| `PROMETHEUS_PORT`        | Prometheus port                                                   | `8192`              |

### Service Parameters

| Parameter      | Description                  | Default     |
| -------------- | ---------------------------- | ----------- |
| `service.type` | Service type                 | `ClusterIP` |
| `service.port` | FlareSolverr HTTP port       | `8191`      |

### Ingress Parameters

| Parameter             | Description                 | Default                          |
| --------------------- | --------------------------- | -------------------------------- |
| `ingress.enabled`     | Enable Ingress              | `false`                          |
| `ingress.className`   | Ingress class name          | `""`                             |
| `ingress.annotations` | Ingress annotations         | `{}`                             |
| `ingress.hosts`       | Ingress hosts configuration | `chart-example.local` (override) |
| `ingress.tls`         | Ingress TLS configuration   | `[]`                             |

### HTTPRoute (Gateway API) Parameters

| Parameter               | Description                                            | Default |
| ----------------------- | ------------------------------------------------------ | ------- |
| `httpRoute.enabled`     | Enable Gateway API HTTPRoute                           | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                                  | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                                       | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments (required when enabled) | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                            | `[]`    |
| `httpRoute.rules`       | Route rules; `backendRefs` default to this service     | `[]`    |

### Cloudflare Tunnel Parameters

| Parameter            | Description                       | Default |
| -------------------- | --------------------------------- | ------- |
| `cfTunnel.enabled`   | Enable Cloudflare Tunnel binding  | `false` |
| `cfTunnel.tunnelRef` | Tunnel reference (`name`, `kind`) | `{}`    |
| `cfTunnel.subjects`  | Tunnel subjects                   | `{}`    |

### Autoscaling Parameters

| Parameter                                       | Description                      | Default |
| ----------------------------------------------- | -------------------------------- | ------- |
| `autoscaling.enabled`                           | Enable horizontal pod autoscaler | `false` |
| `autoscaling.minReplicas`                       | Minimum replicas                 | `1`     |
| `autoscaling.maxReplicas`                       | Maximum replicas                 | `100`   |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU utilization           | `80`    |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization        | `80`    |

### Storage & Scheduling

| Parameter      | Description                  | Default |
| -------------- | ---------------------------- | ------- |
| `volumes`      | Additional volumes           | `[]`    |
| `volumeMounts` | Additional volume mounts     | `[]`    |
| `resources`    | Resource requests and limits | `{}`    |
| `nodeSelector` | Node selector                | `{}`    |
| `tolerations`  | Tolerations                  | `[]`    |
| `affinity`     | Affinity rules               | `{}`    |

## Examples

### Minimal in-cluster install

This is the most common deployment shape: FlareSolverr is consumed only by Prowlarr/Jackett over the cluster network, so it stays on a `ClusterIP` service with no ingress.

```yaml
enabled: true

env:
  - name: LOG_LEVEL
    value: "info"
  - name: TZ
    value: "Europe/Paris"
  - name: BROWSER_TIMEOUT
    value: "40000"
  - name: CAPTCHA_SOLVER
    value: "none"

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

After install, the service is reachable in-cluster at:

```
http://flaresolverr.<namespace>.svc.cluster.local:8191/v1
```

### Larger `/dev/shm` for memory-hungry Chromium

Chromium uses `/dev/shm` (64 MiB by default in Kubernetes) for tab memory. Heavy challenges can exhaust this and cause "Aw, Snap!" tab crashes.

```yaml
enabled: true

env:
  - name: LOG_LEVEL
    value: "info"
  - name: BROWSER_TIMEOUT
    value: "60000"

volumes:
  - name: dshm
    emptyDir:
      medium: Memory
      sizeLimit: 512Mi

volumeMounts:
  - name: dshm
    mountPath: /dev/shm

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

### Gateway API HTTPRoute exposure for cross-cluster Prowlarr

```yaml
enabled: true

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
  hostnames:
    - flaresolverr.internal.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1
```

## Persistence

None. FlareSolverr is stateless. Pods can be rescheduled freely. The browser profile lives in an ephemeral `/tmp` inside the container.

## Integration notes

### Prowlarr

1. In Prowlarr, go to **Settings -> Indexers -> Add Indexer Proxy -> FlareSolverr**.
2. Set **Host**: `http://flaresolverr.<namespace>.svc.cluster.local:8191/`.
3. Add a **Tag** (e.g., `cf`). Apply the same tag on every indexer that needs CF bypass.
4. Test. Prowlarr will POST to `/v1` and expect a `solution.response` in the JSON body.

### Jackett

In Jackett's `ServerConfig.json` (or via the UI on supported versions), set:

```json
{
  "FlareSolverrUrl": "http://flaresolverr.<namespace>.svc.cluster.local:8191/"
}
```

### Direct API smoke test

```bash
kubectl run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl -s -X POST 'http://flaresolverr.<namespace>.svc.cluster.local:8191/v1' \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"request.get","url":"https://www.google.com","maxTimeout":60000}'
```

A `status: ok` response with a `solution.response` HTML body confirms the service is healthy.

## Upgrading

### To 0.3.0

- Added Gateway API `HTTPRoute` and Cloudflare Tunnel `TunnelBinding` templates.

## Uninstallation

```bash
helm uninstall flaresolverr
```

Nothing else to clean up — FlareSolverr is stateless.

## Support

- Upstream FlareSolverr: <https://github.com/FlareSolverr/FlareSolverr>
- Image: <https://github.com/FlareSolverr/FlareSolverr/pkgs/container/flaresolverr>
- Chart Repository Issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. FlareSolverr is licensed under the [MIT License](https://github.com/FlareSolverr/FlareSolverr/blob/master/LICENSE).

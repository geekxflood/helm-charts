# Prowlarr Helm Chart

![Version: 1.1.0](https://img.shields.io/badge/Version-1.1.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 2.0.5](https://img.shields.io/badge/AppVersion-2.0.5-informational?style=flat-square)

[Prowlarr](https://prowlarr.com/) is the indexer manager for the *arr stack. It consolidates trackers and Usenet indexers into a single place and pushes their configuration (URL, API key, categories, syncing rules) to Radarr, Sonarr, Lidarr, and Readarr so you only manage indexer credentials once. This chart runs Prowlarr on Kubernetes via the [LinuxServer.io image](https://hub.docker.com/r/linuxserver/prowlarr) and exposes it with your choice of Ingress, Gateway API HTTPRoute, or Cloudflare Tunnel.

Prowlarr is what you install **first** in an *arr deployment — Radarr/Sonarr/Readarr then connect to it.

## Features

- `Deployment` with `Recreate` strategy — safe with a `ReadWriteOnce` `/config` PVC backing Prowlarr's SQLite store.
- Static-binding `PersistentVolumeClaim` for `/config` (10 GiB default — Prowlarr's footprint is small).
- Service on `ClusterIP:9696` (Prowlarr's default port).
- Three exposure paths: classic `Ingress`, Gateway API `HTTPRoute`, Cloudflare `TunnelBinding`.
- HTTP probes target `/` on port 9696 with conservative timings tuned for slow indexer-sync startup.
- HPA scaffolding included; do not enable in practice — Prowlarr is single-writer.

This chart does **not** include the OpenBao API-key sync init container shipped with the Radarr/Sonarr/Readarr/Bazarr charts. Prowlarr's API key can be exported manually from `Settings → General` and stored in your secret manager out-of-band.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- A `StorageClass` supporting `ReadWriteOnce` for `/config`.
- Optional:
  - [Gateway API CRDs](https://gateway-api.sigs.k8s.io/) if using `httpRoute`.
  - [cloudflare-operator](https://github.com/adyanth/cloudflare-operator) if using `cfTunnel`.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install

```bash
helm install prowlarr geekxflood/prowlarr
helm install prowlarr geekxflood/prowlarr -f values.yaml
```

Prowlarr ships with `enabled: false`. Set `enabled: true` in your `values.yaml` to render workloads.

## Configuration

### Global

| Parameter          | Description                          | Default    |
| ------------------ | ------------------------------------ | ---------- |
| `enabled`          | Master switch                        | `false`    |
| `replicaCount`     | Pod count (keep `1`)                 | `1`        |
| `nameOverride`     | Override the chart name in resources | `""`       |
| `fullnameOverride` | Override the fully qualified name    | `""`       |
| `strategy.type`    | Deployment strategy                  | `Recreate` |

### Image

| Parameter          | Description                                  | Default                |
| ------------------ | -------------------------------------------- | ---------------------- |
| `image.repository` | Container image                              | `linuxserver/prowlarr` |
| `image.tag`        | Image tag (falls back to `Chart.appVersion`) | `"latest"`             |
| `image.pullPolicy` | Image pull policy                            | `Always`               |
| `imagePullSecrets` | Pull secrets list                            | `[]`                   |

### Pod & Service Account

| Parameter                    | Description                  | Default |
| ---------------------------- | ---------------------------- | ------- |
| `serviceAccount.create`      | Create a dedicated SA        | `true`  |
| `serviceAccount.automount`   | Auto-mount SA token          | `true`  |
| `serviceAccount.annotations` | SA annotations               | `{}`    |
| `serviceAccount.name`        | Override SA name             | `""`    |
| `podAnnotations`             | Pod annotations              | `{}`    |
| `podLabels`                  | Pod labels                   | `{}`    |
| `podSecurityContext`         | Pod-level security context   | `{}`    |
| `securityContext`            | Container security context   | `{}`    |
| `env`                        | Container env vars           | `[]`    |

### Service

| Parameter      | Description              | Default     |
| -------------- | ------------------------ | ----------- |
| `service.type` | Kubernetes service type  | `ClusterIP` |
| `service.port` | Service & container port | `9696`      |

### Ingress

| Parameter             | Description         | Default |
| --------------------- | ------------------- | ------- |
| `ingress.enabled`     | Render an `Ingress` | `false` |
| `ingress.className`   | `ingressClassName`  | `""`    |
| `ingress.annotations` | Ingress annotations | `{}`    |
| `ingress.hosts`       | List of host/paths  | `[]`    |
| `ingress.tls`         | TLS secret refs     | `[]`    |

### HTTPRoute (Gateway API)

| Parameter               | Description                                                | Default |
| ----------------------- | ---------------------------------------------------------- | ------- |
| `httpRoute.enabled`     | Render an `HTTPRoute`                                      | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                                      | `{}`    |
| `httpRoute.labels`      | Additional labels                                          | `{}`    |
| `httpRoute.parentRefs`  | Gateways/listeners this route attaches to (required)       | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                                | `[]`    |
| `httpRoute.rules`       | List of `matches` / `filters` / `backendRefs` / `timeouts` | `[]`    |

Omitting `backendRefs[*].name`/`port` falls back to this chart's service on `service.port`.

### Cloudflare Tunnel

| Parameter            | Description                              | Default |
| -------------------- | ---------------------------------------- | ------- |
| `cfTunnel.enabled`   | Render a `TunnelBinding`                 | `false` |
| `cfTunnel.tunnelRef` | Reference to a `ClusterTunnel`/`Tunnel`  | `{}`    |
| `cfTunnel.subjects`  | Tunnel subjects (defaults to the service) | `[]`   |

### Persistence (`/config`)

| Parameter                  | Description                                              | Default                |
| -------------------------- | -------------------------------------------------------- | ---------------------- |
| `persistence.enabled`      | Render the config PVC                                    | `false`                |
| `persistence.name`         | PVC name override (default `<release>-config-iscsi-pvc`) | `""`                   |
| `persistence.storageClass` | Storage class                                            | `""` (cluster default) |
| `persistence.accessMode`   | PVC access mode                                          | `ReadWriteOnce`        |
| `persistence.size`         | Requested storage                                        | `10Gi`                 |
| `persistence.volumeName`   | Bind to a specific `PersistentVolume`                    | `""`                   |

### Volumes / Volume Mounts

| Parameter      | Description                         | Default |
| -------------- | ----------------------------------- | ------- |
| `volumes`      | Additional `pod.spec.volumes`       | `[]`    |
| `volumeMounts` | Additional `container.volumeMounts` | `[]`    |

### Probes

| Parameter        | Description                         | Default                        |
| ---------------- | ----------------------------------- | ------------------------------ |
| `livenessProbe`  | Liveness probe (HTTP GET `/`:9696)  | `initialDelay 60s, period 60s` |
| `readinessProbe` | Readiness probe (HTTP GET `/`:9696) | `initialDelay 30s, period 30s` |

### Resources & Scheduling

| Parameter      | Description                    | Default |
| -------------- | ------------------------------ | ------- |
| `resources`    | CPU / memory requests & limits | `{}`    |
| `nodeSelector` | `pod.spec.nodeSelector`        | `{}`    |
| `tolerations`  | `pod.spec.tolerations`         | `[]`    |
| `affinity`     | `pod.spec.affinity`            | `{}`    |

### Autoscaling (HPA)

| Parameter                                       | Description   | Default |
| ----------------------------------------------- | ------------- | ------- |
| `autoscaling.enabled`                           | Render an HPA | `false` |
| `autoscaling.minReplicas`                       | Min replicas  | `1`     |
| `autoscaling.maxReplicas`                       | Max replicas  | `100`   |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU    | `80`    |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory | `80`    |

## Examples

### Basic install with Ingress

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: TZ
    value: "Europe/Paris"

persistence:
  enabled: true
  size: 5Gi
  storageClass: longhorn

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: prowlarr-config-iscsi-pvc

volumeMounts:
  - name: config
    mountPath: /config

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: prowlarr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - prowlarr.example.com
      secretName: prowlarr-tls
```

### HTTPRoute + Cloudflare Tunnel

```yaml
enabled: true

ingress:
  enabled: false

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - prowlarr.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1

cfTunnel:
  enabled: true
  tunnelRef:
    kind: ClusterTunnel
    name: prod-tunnel
```

CLI equivalent for a minimal HTTPRoute install:

```bash
helm install prowlarr geekxflood/prowlarr \
  --set enabled=true \
  --set httpRoute.enabled=true \
  --set 'httpRoute.parentRefs[0].name=cilium-gateway' \
  --set 'httpRoute.parentRefs[0].namespace=gateway-system' \
  --set 'httpRoute.hostnames[0]=prowlarr.example.com' \
  --set 'httpRoute.rules[0].matches[0].path.value=/' \
  --set 'httpRoute.rules[0].backendRefs[0].weight=1'
```

## Persistence

Prowlarr is light: a single `/config` PVC holds its SQLite DB, indexer definitions, and per-app sync state. 5–10 GiB is plenty. There are no media or download volumes — Prowlarr only proxies indexer search calls; it never touches the library.

| Mount     | Purpose                                          | Provided by chart?       |
| --------- | ------------------------------------------------ | ------------------------ |
| `/config` | SQLite DB, indexer configs, app sync state       | Yes, via `persistence.*` |

## Integration notes

Prowlarr is the indexer hub. The flow is:

1. Add indexers in Prowlarr (`Indexers → Add Indexer`).
2. Add the consuming apps in `Settings → Apps` — one entry each for Radarr, Sonarr, Readarr, Lidarr — with their service URL and API key:
   - Radarr: `http://<radarr-release>.<namespace>.svc:7878`
   - Sonarr: `http://<sonarr-release>.<namespace>.svc:8989`
   - Readarr: `http://<readarr-release>.<namespace>.svc:8787`
3. Prowlarr syncs every enabled indexer into each app automatically. From that point on, you maintain indexer credentials only in Prowlarr.

The API keys you paste into Prowlarr's "Apps" page come from each consuming app's own `Settings → General`. If you enabled OpenBao sync on Radarr/Sonarr/Readarr (see those charts), retrieve them from your KV store.

## Upgrading

`persistence.volumeName` enables static PV binding. To carry an existing `/config` volume across reinstalls, capture the current PV (`kubectl get pvc <pvc-name> -o jsonpath='{.spec.volumeName}'`) and pass it as `persistence.volumeName`.

## Support

- Upstream: <https://prowlarr.com/> · [GitHub](https://github.com/Prowlarr/Prowlarr)
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. Prowlarr is licensed under [GPL-3.0](https://github.com/Prowlarr/Prowlarr/blob/develop/LICENSE).

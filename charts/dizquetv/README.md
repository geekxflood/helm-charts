# dizqueTV Helm Chart

![Version: 0.2.1](https://img.shields.io/badge/Version-0.2.1-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.7.0](https://img.shields.io/badge/AppVersion-1.7.0-informational?style=flat-square)

[dizqueTV](https://github.com/vexorian/dizquetv) turns the contents of a Plex (or Jellyfin) library into fake live TV channels with EPG and HDHomeRun emulation, so your media server's DVR can record from them and clients see real "channels" instead of an on-demand grid. Deploy this chart when you want that nostalgic "what's on right now" experience on top of an existing media collection. dizqueTV is the predecessor of [Tunarr](https://tunarr.com/), which is a clean reimplementation by the same community — pick dizqueTV if you have legacy channel data to preserve; pick Tunarr for new installs.

## Features

- HTTP `Ingress` and Gateway API `HTTPRoute` exposure
- Cloudflare Tunnel `TunnelBinding` for external access
- HPA wiring (`autoscaling.enabled`) — note: not recommended for a stateful streamer
- Optional `runtimeClassName` selection for nodes with specific runtime (e.g. for hardware encoders)
- Plain `volumes`/`volumeMounts` arrays — you bring the PVCs (config + media libraries)
- `envFrom` support for `Secret` / `ConfigMap` references

## Prerequisites

- Kubernetes 1.19+ (HTTPRoute needs Gateway API CRDs `gateway.networking.k8s.io/v1`)
- Helm 3.0+
- A pre-provisioned PVC for `/home/node/app/.dizquetv` (config + channel database)
- Access to your Plex/Jellyfin server from inside the cluster
- Existing PVCs for any media you want dizqueTV to read directly (optional — most users let Plex serve the media and just point dizqueTV at it via API)
- Optional: cloudflare-operator if `cfTunnel.enabled=true`

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install with default values

```bash
helm install dizquetv geekxflood/dizquetv --set enabled=true
```

Note: `enabled` defaults to `false` in `values.yaml`, so nothing renders until you flip it.

### Install with custom values

```bash
helm install dizquetv geekxflood/dizquetv -f values.yaml
```

## Configuration

### Image

| Parameter          | Description       | Default              |
| ------------------ | ----------------- | -------------------- |
| `enabled`          | Render manifests  | `false`              |
| `image.repository` | Image repository  | `vexorian/dizquetv`  |
| `image.tag`        | Image tag         | `1.7.0`              |
| `image.pullPolicy` | Image pull policy | `IfNotPresent`       |
| `replicaCount`     | Replica count     | `1`                  |

### Service

| Parameter      | Description  | Default     |
| -------------- | ------------ | ----------- |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8000`      |

### Environment

| Parameter  | Description                                        | Default |
| ---------- | -------------------------------------------------- | ------- |
| `env`      | List of `{name, value}` env vars                   | `[]`    |
| `envFrom`  | Refs into Secret / ConfigMap: `{type, name}` items | `[]`    |

`envFrom[*].type` must be `secret` or `configmap`; the template renders the matching `secretRef` / `configMapRef`.

### Ingress

| Parameter             | Description         | Default                                      |
| --------------------- | ------------------- | -------------------------------------------- |
| `ingress.enabled`     | Enable Ingress      | `false`                                      |
| `ingress.className`   | IngressClass name   | `""`                                         |
| `ingress.annotations` | Ingress annotations | `{}`                                         |
| `ingress.hosts`       | Host rules          | `[{host: chart-example.local, paths: [...]}]` |
| `ingress.tls`         | TLS configuration   | `[]`                                         |

### HTTPRoute (Gateway API)

| Parameter               | Description                                            | Default |
| ----------------------- | ------------------------------------------------------ | ------- |
| `httpRoute.enabled`     | Enable Gateway API HTTPRoute                           | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                                  | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                                       | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments (required when enabled) | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                            | `[]`    |
| `httpRoute.rules`       | Route rules (matches + backendRefs)                    | `[]`    |

Omit `backendRefs[*].name`/`port` and the route defaults to this chart's service on `service.port` (8000).

### Cloudflare Tunnel

| Parameter            | Description                            | Default |
| -------------------- | -------------------------------------- | ------- |
| `cfTunnel.enabled`   | Render a `TunnelBinding`               | `false` |
| `cfTunnel.tunnelRef` | Tunnel reference (`{name, kind}`)      | `{}`    |
| `cfTunnel.subjects`  | Tunnel subjects (services + FQDNs)     | `{}`    |

### Runtime, Resources, Storage

| Parameter         | Description                            | Default |
| ----------------- | -------------------------------------- | ------- |
| `runtime.enabled` | Set `runtimeClassName` on the pod      | `false` |
| `runtime.name`    | RuntimeClass name (e.g. `nvidia`)      | `""`    |
| `resources`       | Resource requests/limits               | `{}`    |
| `volumes`         | Pod volumes (config, media, etc.)      | `[]`    |
| `volumeMounts`    | Container volume mounts                | `[]`    |

### Autoscaling

| Parameter                                       | Description               | Default |
| ----------------------------------------------- | ------------------------- | ------- |
| `autoscaling.enabled`                           | Enable HPA                | `false` |
| `autoscaling.minReplicas`                       | Min replicas              | `1`     |
| `autoscaling.maxReplicas`                       | Max replicas              | `100`   |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU %              | `80`    |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory %           | `80`    |

dizqueTV writes to a local SQLite-style channel DB; running more than one replica against the same PVC will corrupt state. Keep autoscaling off unless you know what you're doing.

## Examples

### Single-replica with Ingress

```yaml
enabled: true

image:
  tag: "1.7.0"

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
  hosts:
    - host: dizquetv.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: dizquetv-tls
      hosts:
        - dizquetv.example.com

env:
  - name: TZ
    value: "Europe/Berlin"

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: dizquetv-config
  - name: media
    persistentVolumeClaim:
      claimName: media-readonly

volumeMounts:
  - name: config
    mountPath: /home/node/app/.dizquetv
  - name: media
    mountPath: /media
    readOnly: true
```

CLI equivalent for a minimal install:

```bash
helm install dizquetv geekxflood/dizquetv \
  --set enabled=true \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set 'ingress.hosts[0].host=dizquetv.example.com' \
  --set 'ingress.hosts[0].paths[0].path=/' \
  --set 'ingress.hosts[0].paths[0].pathType=Prefix'
```

### Gateway API HTTPRoute behind Cilium

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
    - dizquetv.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: dizquetv-config

volumeMounts:
  - name: config
    mountPath: /home/node/app/.dizquetv
```

Cilium operators: `parentRefs[*].port` is ignored — target a listener via `sectionName`. Cross-namespace `backendRefs` require a `ReferenceGrant` in the backend namespace.

## Persistence

dizqueTV stores everything — channel definitions, programs, schedules, settings — in `/home/node/app/.dizquetv`. Mount a PVC there. Without it, every pod restart wipes your channels.

Media is **not** copied or owned by dizqueTV. It references file paths that exist on your Plex/Jellyfin server. If you mount media into the pod (e.g. `/media`), the paths inside dizqueTV must match what those upstream servers see.

## Upgrading

This chart still uses a hard-coded `nameOverride`/`fullnameOverride` empty default and a 1.x app version. Before upgrading the app image, snapshot your config PVC — dizqueTV's database schema changes between minor versions and downgrades are not supported.

```bash
kubectl exec deploy/dizquetv -- tar czf - /home/node/app/.dizquetv > dizquetv-backup-$(date +%F).tgz
```

If you are starting fresh, evaluate [Tunarr](https://tunarr.com/) instead — it's the maintained successor and this repository ships a chart for it as well.

## Support

- Upstream project: <https://github.com/vexorian/dizquetv>
- Tunarr (successor): <https://github.com/chrisbenincasa/tunarr>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. dizqueTV is distributed under the [zlib license](https://github.com/vexorian/dizquetv/blob/main/LICENSE) by the upstream project.

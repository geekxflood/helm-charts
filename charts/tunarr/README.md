# Tunarr Helm Chart

![Version: 0.5.0](https://img.shields.io/badge/Version-0.5.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.2.17](https://img.shields.io/badge/AppVersion-1.2.17-informational?style=flat-square)

[Tunarr](https://tunarr.com/) is the maintained successor to dizqueTV. It composes live TV channels — with EPG and built-in HDHomeRun emulation — out of media that lives on a Plex, Jellyfin, or Emby server. Plex DVR can tune Tunarr like a real tuner and record from it. Deploy this chart when you want a "what's on tonight" experience over a media library you already have, without buying an antenna.

## Features

- HTTP `Ingress` and Gateway API `HTTPRoute` exposure
- Cloudflare Tunnel `TunnelBinding` integration
- NVIDIA GPU passthrough with automatic `nvidia.com/gpu` resource injection, `runtimeClassName`, and `NVIDIA_*` env vars
- Optional managed PVC for config (`/root/.local/share/tunarr`) with `existingClaim` reuse support
- HTTP probes against `/api/version` — the deployment is unhealthy until the Tunarr API responds
- `envFrom` support for `Secret` / `ConfigMap` references (e.g. for Plex tokens)
- Optional registry override (`image.registry`) on top of `repository`/`tag`

## Prerequisites

- Kubernetes 1.19+ (Gateway API CRDs `gateway.networking.k8s.io/v1` if `httpRoute.enabled=true`)
- Helm 3.0+
- A reachable Plex / Jellyfin / Emby server with a token you can hand to Tunarr through its UI
- A PV provisioner if `persistence.enabled=true` and no `existingClaim` is supplied
- For GPU transcoding: NVIDIA GPU Operator, a working `RuntimeClass`, and a GPU-labeled node
- Optional: cloudflare-operator if `cfTunnel.enabled=true`

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install with default values

```bash
helm install tunarr geekxflood/tunarr --set enabled=true
```

Note: `enabled` defaults to `false` — manifests do not render until you set it to `true`.

### Install with custom values

```bash
helm install tunarr geekxflood/tunarr -f values.yaml
```

## Configuration

### Image

| Parameter          | Description                          | Default                 |
| ------------------ | ------------------------------------ | ----------------------- |
| `enabled`          | Render manifests                     | `false`                 |
| `image.registry`   | Optional registry prefix             | `""`                    |
| `image.repository` | Image repository                     | `chrisbenincasa/tunarr` |
| `image.tag`        | Image tag (defaults to `appVersion`) | `""`                    |
| `image.pullPolicy` | Image pull policy                    | `IfNotPresent`          |
| `replicaCount`     | Replica count                        | `1`                     |

### Service

| Parameter      | Description                      | Default     |
| -------------- | -------------------------------- | ----------- |
| `service.type` | Service type                     | `ClusterIP` |
| `service.port` | Web UI + HDHomeRun emulator port | `8000`      |

### Environment

| Parameter | Description                                        | Default |
| --------- | -------------------------------------------------- | ------- |
| `env`     | List of `{name, value}` env vars                   | `[]`    |
| `envFrom` | Refs into Secret / ConfigMap: `{type, name}` items | `[]`    |

`envFrom[*].type` must be `secret` or `configmap`.

### Ingress

| Parameter             | Description         | Default |
| --------------------- | ------------------- | ------- |
| `ingress.enabled`     | Enable Ingress      | `false` |
| `ingress.className`   | IngressClass name   | `""`    |
| `ingress.annotations` | Ingress annotations | `{}`    |
| `ingress.hosts`       | Host rules          | `[]`    |
| `ingress.tls`         | TLS configuration   | `[]`    |

### HTTPRoute (Gateway API)

| Parameter               | Description                                            | Default |
| ----------------------- | ------------------------------------------------------ | ------- |
| `httpRoute.enabled`     | Enable Gateway API HTTPRoute                           | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                                  | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                                       | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments (required when enabled) | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                            | `[]`    |
| `httpRoute.rules`       | Route rules (matches + backendRefs)                    | `[]`    |

Omitted `backendRefs[*].name`/`port` target this chart's service on `service.port` (8000).

### Cloudflare Tunnel

| Parameter            | Description                            | Default |
| -------------------- | -------------------------------------- | ------- |
| `cfTunnel.enabled`   | Render a `TunnelBinding`               | `false` |
| `cfTunnel.tunnelRef` | Reference (`{name, kind}`) to a Tunnel | `{}`    |
| `cfTunnel.subjects`  | Subjects list (services + FQDNs)       | `[]`    |

### GPU (NVIDIA)

| Parameter          | Description                          | Default  |
| ------------------ | ------------------------------------ | -------- |
| `gpu.enabled`      | Enable GPU passthrough               | `false`  |
| `gpu.runtimeClass` | RuntimeClass set on the pod          | `nvidia` |
| `gpu.count`        | `nvidia.com/gpu` request/limit count | `1`      |

### Persistence

| Parameter                   | Description                           | Default         |
| --------------------------- | ------------------------------------- | --------------- |
| `persistence.enabled`       | Create a config PVC                   | `false`         |
| `persistence.existingClaim` | Reuse an existing PVC (skip creation) | `""`            |
| `persistence.storageClass`  | Storage class                         | `""`            |
| `persistence.accessMode`    | Access mode                           | `ReadWriteOnce` |
| `persistence.size`          | PVC size                              | `1Gi`           |
| `volumes`                   | Additional pod volumes (media, etc.)  | `[]`            |
| `volumeMounts`              | Additional container volume mounts    | `[]`            |

When `persistence.enabled=true`, the chart mounts the PVC at `/root/.local/share/tunarr` automatically — do not also declare it in `volumes`/`volumeMounts`.

### Resources & Scheduling

| Parameter             | Description                                     | Default |
| --------------------- | ----------------------------------------------- | ------- |
| `resources`           | CPU/memory requests and limits                  | `{}`    |
| `nodeSelector`        | Node selector                                   | `{}`    |
| `affinity`            | Affinity rules                                  | `{}`    |
| `tolerations`         | Tolerations                                     | `[]`    |
| `autoscaling.enabled` | Enable HPA (not recommended — single-writer DB) | `false` |

Tunarr keeps its channel state on disk. Multiple replicas pointing at the same PVC will corrupt that state — leave `autoscaling.enabled=false`.

## Examples

### Ingress with persistent config and read-only media

```yaml
enabled: true

image:
  tag: "1.2.17"

env:
  - name: TZ
    value: "America/Los_Angeles"
  - name: LOG_LEVEL
    value: "info"

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
  hosts:
    - host: tunarr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: tunarr-tls
      hosts:
        - tunarr.example.com

persistence:
  enabled: true
  storageClass: fast-ssd
  size: 5Gi

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 2000m
    memory: 2Gi

volumes:
  - name: movies
    persistentVolumeClaim:
      claimName: movies

volumeMounts:
  - name: movies
    mountPath: /media/movies
    readOnly: true
```

### NVIDIA GPU transcoding + HTTPRoute + Plex DVR tuner

This shape exposes Tunarr through Cilium Gateway API, uses GPU hardware acceleration for the FFmpeg pipeline, and reuses an existing config PVC so an upgrade can't accidentally re-provision storage.

```yaml
enabled: true

gpu:
  enabled: true
  runtimeClass: nvidia
  count: 1

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 4000m
    memory: 4Gi

nodeSelector:
  nvidia.com/gpu.present: "true"

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - tunarr.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1

persistence:
  enabled: true
  existingClaim: tunarr-config

envFrom:
  - type: secret
    name: tunarr-plex-token
```

After install, Plex DVR can be pointed at `tunarr.example.com:8000` as an HDHomeRun tuner. Cilium operators: `parentRefs[*].port` is ignored — target a listener via `sectionName`. Cross-namespace `backendRefs` require a `ReferenceGrant`.

## Persistence

Tunarr keeps its channel/program database under `/root/.local/share/tunarr` inside the container. There are two ways to back it with a PVC:

1. Let the chart provision one: set `persistence.enabled=true` and (optionally) `persistence.storageClass` and `persistence.size`.
2. Reuse an existing PVC: set `persistence.enabled=true` and `persistence.existingClaim=<name>`. The chart will mount it but won't render a new `PersistentVolumeClaim`.

Media files do not belong to Tunarr — it reads them via your Plex/Jellyfin/Emby API. If you also want raw filesystem access (e.g. for transcoding), mount the media PVC read-only via `volumes`/`volumeMounts`.

Snapshot the config PVC before any major image bump:

```bash
kubectl exec deploy/tunarr -- tar czf - /root/.local/share/tunarr > tunarr-backup-$(date +%F).tgz
```

## Upgrading

Tunarr is still 1.x and schema-migrates forward on startup. Downgrades aren't supported. Bumping the chart minor version generally does not change PVC layout; bumping the app `image.tag` may. Always back up the config PVC first.

Migrating from dizqueTV? Tunarr ships an importer in the UI — see <https://tunarr.com/docs>.

## Support

- Upstream project: <https://tunarr.com/> — source at <https://github.com/chrisbenincasa/tunarr>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. Tunarr is licensed under the [zlib license](https://github.com/chrisbenincasa/tunarr/blob/main/LICENSE).

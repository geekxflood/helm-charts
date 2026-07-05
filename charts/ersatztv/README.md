# ErsatzTV Helm Chart

![Version: 1.3.0](https://img.shields.io/badge/Version-1.3.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: v25.2.0](https://img.shields.io/badge/AppVersion-v25.2.0-informational?style=flat-square)

[ErsatzTV](https://ersatztv.org/) builds custom live TV channels out of your existing media — local files, Plex, Jellyfin, or Emby — and serves them as M3U playlists with XMLTV EPG. Drop it in front of a media server with a DVR and you have a programmable 24/7 broadcaster: themed channels, scheduled blocks, ad-style filler, the whole 1990s cable experience on top of files you already own. Hardware transcoding via NVIDIA is supported when the cluster is configured for it.

## Features

- HTTP `Ingress` and Gateway API `HTTPRoute` exposure (use either or both)
- NVIDIA GPU passthrough with automatic `nvidia.com/gpu` resource requests, `runtimeClassName`, and `NVIDIA_*` env injection
- Optional in-memory tmpfs transcode scratch (`/transcode`) to save SSD writes
- Optional xTeVe sidecar that emulates an HDHomeRun for Plex DVR compatibility — its own port, probes, and PVC
- A chart-managed config PVC (configurable via `persistence.*`, default name `ersatztv-config-pvc`) plus an opt-in xTeVe PVC
- Plain `volumes`/`volumeMounts` for mounting your media libraries (typically read-only)
- Long startup probe on xTeVe (up to ~6.5 min) — first-boot Perl module install will not flap the deployment

## Prerequisites

- Kubernetes 1.19+ (Gateway API CRDs `gateway.networking.k8s.io/v1` if `httpRoute.enabled=true`)
- Helm 3.0+
- A default StorageClass for the chart's config PVC, or set `persistence.storageClass` explicitly
- For GPU transcoding: NVIDIA GPU Operator, a working `RuntimeClass`, and nodes labeled with `nvidia.com/gpu.present`
- Existing PVCs for your media library (movies, shows, etc.) — the chart does not provision them
- A Plex / Jellyfin / Emby server reachable from the cluster (optional but typical)

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install with default values

```bash
helm install ersatztv geekxflood/ersatztv --set enabled=true
```

Note: `enabled` defaults to `false`. Until you set it to `true`, no manifests render.

### Install with custom values

```bash
helm install ersatztv geekxflood/ersatztv -f values.yaml
```

## Configuration

### Image

| Parameter          | Description       | Default                     |
| ------------------ | ----------------- | --------------------------- |
| `enabled`          | Render manifests  | `false`                     |
| `image.repository` | Image repository  | `ghcr.io/ersatztv/ersatztv` |
| `image.tag`        | Image tag         | `latest`                    |
| `image.pullPolicy` | Image pull policy | `Always`                    |
| `replicaCount`     | Replica count     | `1`                         |

### Service

| Parameter      | Description  | Default     |
| -------------- | ------------ | ----------- |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8409`      |

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

Omitting `backendRefs[*].name`/`port` targets this chart's service on `service.port` (8409). IPTV clients reaching the same hostname through the Gateway will hit `/iptv/channels.m3u` and `/iptv/xmltv.xml`.

### GPU (NVIDIA)

| Parameter          | Description                          | Default  |
| ------------------ | ------------------------------------ | -------- |
| `gpu.enabled`      | Enable GPU passthrough               | `false`  |
| `gpu.runtimeClass` | RuntimeClass set on the pod          | `nvidia` |
| `gpu.count`        | `nvidia.com/gpu` request/limit count | `1`      |

When `gpu.enabled=true`, the chart sets `runtimeClassName`, adds `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=all` to the env, and merges `nvidia.com/gpu: <count>` into both `resources.requests` and `resources.limits`.

### tmpfs Transcode Scratch

| Parameter         | Description                                   | Default |
| ----------------- | --------------------------------------------- | ------- |
| `tmpfs.enabled`   | Mount an in-memory `emptyDir` at `/transcode` | `false` |
| `tmpfs.sizeLimit` | tmpfs `sizeLimit`                             | `10Gi`  |

### xTeVe Sidecar (HDHomeRun emulator)

| Parameter                         | Description                         | Default                                   |
| --------------------------------- | ----------------------------------- | ----------------------------------------- |
| `xteve.enabled`                   | Enable xTeVe sidecar                | `false`                                   |
| `xteve.image.repository`          | Sidecar image                       | `dnsforge/xteve`                          |
| `xteve.image.tag`                 | Sidecar tag                         | `latest`                                  |
| `xteve.image.pullPolicy`          | Sidecar pull policy                 | `IfNotPresent`                            |
| `xteve.port`                      | xTeVe web UI / HDHomeRun port       | `34400`                                   |
| `xteve.timezone`                  | `TZ` env                            | `UTC`                                     |
| `xteve.m3uUrl`                    | ErsatzTV M3U the sidecar pulls      | `http://localhost:8409/iptv/channels.m3u` |
| `xteve.xmltvUrl`                  | ErsatzTV XMLTV the sidecar pulls    | `http://localhost:8409/iptv/xmltv.xml`    |
| `xteve.resources`                 | Sidecar resources                   | small defaults; see `values.yaml`         |
| `xteve.persistence.enabled`       | Create a PVC for `/home/xteve/conf` | `true`                                    |
| `xteve.persistence.existingClaim` | Reuse an existing PVC               | `""`                                      |
| `xteve.persistence.storageClass`  | xTeVe PVC storage class             | `""`                                      |
| `xteve.persistence.accessMode`    | xTeVe PVC access mode               | `ReadWriteOnce`                           |
| `xteve.persistence.size`          | xTeVe PVC size                      | `1Gi`                                     |

### Resources, Volumes, Scheduling

| Parameter      | Description                            | Default |
| -------------- | -------------------------------------- | ------- |
| `resources`    | CPU/memory requests and limits         | `{}`    |
| `volumes`      | Additional pod volumes (config, media) | `[]`    |
| `volumeMounts` | Additional container volume mounts     | `[]`    |
| `nodeSelector` | Node selector                          | `{}`    |
| `affinity`     | Affinity rules                         | `{}`    |
| `tolerations`  | Tolerations                            | `[]`    |
| `env`          | List of `{name, value}` env vars       | `[]`    |

## Examples

### Plex / Jellyfin media library with Ingress

```yaml
enabled: true

env:
  - name: TZ
    value: "America/Chicago"

ingress:
  enabled: true
  className: cilium
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: ersatztv.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: ersatztv-tls
      hosts:
        - ersatztv.example.com

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: ersatztv-config-pvc
  - name: movies
    persistentVolumeClaim:
      claimName: movies
  - name: shows
    persistentVolumeClaim:
      claimName: tv-shows

volumeMounts:
  - name: config
    mountPath: /config
  - name: movies
    mountPath: /media/movies
    readOnly: true
  - name: shows
    mountPath: /media/shows
    readOnly: true
```

IPTV consumers can then point at:

- M3U: `https://ersatztv.example.com/iptv/channels.m3u`
- XMLTV: `https://ersatztv.example.com/iptv/xmltv.xml`

### NVIDIA GPU transcoding + tmpfs scratch + xTeVe DVR

This is the "I want Plex to record fake channels" shape: GPU-accelerated FFmpeg, ramdisk transcode scratch to spare the SSD, and the xTeVe sidecar exposed as an HDHomeRun tuner that Plex DVR can subscribe to.

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

tmpfs:
  enabled: true
  sizeLimit: 16Gi

xteve:
  enabled: true
  timezone: "America/Chicago"
  persistence:
    enabled: true
    size: 1Gi

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - ersatztv.example.com
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
      claimName: ersatztv-config-pvc
  - name: media
    persistentVolumeClaim:
      claimName: media-library
    # readOnly handled below

volumeMounts:
  - name: config
    mountPath: /config
  - name: media
    mountPath: /media
    readOnly: true
```

Notes:

- GPU passthrough only works on Linux nodes with the NVIDIA container runtime — Docker Desktop on Mac/Windows will not work.
- xTeVe's first startup installs Perl modules and can take several minutes; the chart sets `failureThreshold: 36` on the startup probe to tolerate this.
- Inside the pod, xTeVe pulls from `http://localhost:8409`, so the M3U/XMLTV URLs in `xteve.*` are pod-internal — no extra exposure needed.

## Persistence

ErsatzTV needs persistent storage in two places.

| Volume       | Mount path                      | Provided by                                  | Purpose                              |
| ------------ | ------------------------------- | -------------------------------------------- | ------------------------------------ |
| config       | `/config`                       | Chart-managed PVC (`persistence.*`)          | Channel DB, scheduling, FFmpeg cache |
| xteve-config | `/home/xteve/conf`              | Chart-managed PVC or `existingClaim`         | xTeVe channel/tuner mapping          |
| media        | your choice (e.g. `/media/...`) | You — via `volumes`/`volumeMounts`           | Source media files (read-only)       |
| transcode    | `/transcode`                    | tmpfs `emptyDir` if `tmpfs.enabled`          | FFmpeg working set                   |

The config PVC is configurable:

| Parameter                  | Description                                            | Default               |
| -------------------------- | ------------------------------------------------------ | --------------------- |
| `persistence.enabled`      | Create the config PVC                                  | `true`                |
| `persistence.name`         | PVC name (referenced from `volumes[]`)                 | `ersatztv-config-pvc` |
| `persistence.storageClass` | Storage class; empty uses the cluster default          | `""`                  |
| `persistence.size`         | Requested storage                                      | `10Gi`                |
| `persistence.accessModes`  | PVC access modes                                       | `[ReadWriteOnce]`     |

Set `persistence.enabled=false` to manage the config PVC outside the chart (keep referencing it via `volumes[]`).

## Upgrading

### To 1.3.0

The config PVC no longer forces a site-specific `storageClassName`; it now uses the cluster's default StorageClass unless `persistence.storageClass` is set. Existing installs that relied on the old hard-coded class must set `persistence.storageClass` to the class their existing claim was created with to keep rendering the same PVC spec.

### General

ErsatzTV's database schema migrates forward on startup and **does not support downgrades**. Always snapshot the config PVC before upgrading the app image:

```bash
kubectl exec deploy/ersatztv -- tar czf - /config > ersatztv-config-$(date +%F).tgz
```

Then `helm upgrade ersatztv geekxflood/ersatztv -f values.yaml`.

## Support

- Upstream project: <https://ersatztv.org/> — source at <https://github.com/ErsatzTV/ErsatzTV>
- xTeVe sidecar: <https://github.com/xteve-project/xTeVe-Documentation>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. ErsatzTV is licensed under the [MIT License](https://github.com/ErsatzTV/ErsatzTV/blob/main/LICENSE).

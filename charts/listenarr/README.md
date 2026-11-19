# Listenarr Helm Chart

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: canary-1.9.2](https://img.shields.io/badge/AppVersion-canary--1.9.2-informational?style=flat-square)

[Listenarr](https://github.com/Listenarrs/Listenarr) automates an audiobook collection the way Sonarr and Radarr do for TV and movies: it searches torrent and Usenet indexers, sends releases to a download client (qBittorrent, Transmission, SABnzbd, NZBGet), and imports and renames finished downloads into an audiobook library, with metadata from Audible and Amazon.

> Listenarr is beta software and upstream publishes only pre-release images (`canary`, `canary-X.Y.Z`, `beta`). The chart pins `canary-<version>` through `appVersion`.

## Features

- Separate `library` and `downloads` volumes (existing claims, optional `subPath`, configurable mount paths) so the download client's directory and a shared audiobook library can be mounted next to the config
- Optional managed PVC for `/app/config` (SQLite database, `config.json`, logs, backups) with `existingClaim` reuse
- HTTP `Ingress` and Gateway API `HTTPRoute` exposure
- `env` entries with `value` or `valueFrom`, plus `envFrom` for `Secret` / `ConfigMap` references
- Readiness on the anonymous `/api/v1/system/ready` endpoint; liveness and startup on TCP so a long startup library scan does not restart the pod
- Every resource gated by `enabled`

## Prerequisites

- Kubernetes 1.19+ (Gateway API CRDs `gateway.networking.k8s.io/v1` if `httpRoute.enabled=true`)
- Helm 3.0+
- A PV provisioner if `persistence.enabled=true` and no `existingClaim` is supplied
- Existing PVCs (ReadWriteMany when shared) if `library.enabled` or `downloads.enabled` is true

## Installation

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm install listenarr geekxflood/listenarr \
  --set enabled=true \
  --set persistence.enabled=true \
  --set library.enabled=true \
  --set library.existingClaim=my-audiobooks-pvc \
  --set downloads.enabled=true \
  --set downloads.existingClaim=my-downloads-pvc
```

## First-time setup

1. **Authentication**: in Settings → General, turn on authentication. The API key shown there is stored in `/app/config/config.json`.
2. **Root folder**: add `library.mountPath` (default `/audiobooks`) in Settings → Media Management.
3. **Download client**: add it in Settings → Download Clients. If the client reports download paths that differ from `downloads.mountPath` (for example a client running outside the cluster), add a Remote Path Mapping from the client's path to the mounted one.
4. **Indexers from Prowlarr**: Settings → Indexers → *Import from Prowlarr*, with the Prowlarr URL and API key. By default only indexers with audiobook categories are imported; set a tag filter to narrow it.

## Configuration

| Key | Default | Description |
| --- | ------- | ----------- |
| `enabled` | `false` | Render the chart's resources |
| `image.registry` | `ghcr.io` | Image registry |
| `image.repository` | `listenarrs/listenarr` | Image repository |
| `image.tag` | `""` | Image tag, defaults to `appVersion` |
| `env` | `PUID`, `PGID`, `UMASK`, `TZ`, `LISTENARR_LOG_LEVEL` | Container variables (`value` or `valueFrom`); `ASPNETCORE_URLS` is set by the chart from `service.port` |
| `envFrom` | `[]` | `{type: secret\|configmap, name}` references |
| `service.port` | `4545` | Service and container port |
| `persistence.enabled` | `false` | Persist `/app/config` |
| `persistence.existingClaim` | `""` | Reuse an existing PVC instead of creating `<fullname>-config` |
| `persistence.size` | `5Gi` | Size of the created PVC |
| `library.enabled` | `false` | Mount the audiobook library |
| `library.existingClaim` | `""` | PVC to mount (required when enabled) |
| `library.subPath` | `""` | Sub-directory of the PVC to mount |
| `library.mountPath` | `/audiobooks` | Where the library is mounted |
| `downloads.enabled` | `false` | Mount the download client's directory |
| `downloads.existingClaim` | `""` | PVC to mount (required when enabled) |
| `downloads.subPath` | `""` | Sub-directory of the PVC to mount |
| `downloads.mountPath` | `/downloads` | Where the downloads are mounted |
| `volumes` / `volumeMounts` | `[]` | Extra volumes, e.g. a second download client |
| `httpRoute.enabled` | `false` | Create a Gateway API `HTTPRoute` |
| `ingress.enabled` | `false` | Create an `Ingress` |
| `podSecurityContext` / `securityContext` | `{}` | The image starts as root and drops to `PUID`/`PGID` after a `chown -R /app/config` |
| `startupProbe` / `livenessProbe` | TCP `http` | Probe overrides |
| `readinessProbe` | HTTP `GET /api/v1/system/ready` | Probe override |

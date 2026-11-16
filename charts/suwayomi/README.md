# Suwayomi-Server Helm Chart

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: v2.4.2366](https://img.shields.io/badge/AppVersion-v2.4.2366-informational?style=flat-square)

[Suwayomi-Server](https://github.com/Suwayomi/Suwayomi-Server) is a self-hosted reader and downloader for manga, manhwa and webtoons. It uses Tachiyomi / Mihon extension sources and serves a web UI and a GraphQL API. Deploy this chart when you want chapters downloaded on a schedule into a volume that a comic-capable media server (Jellyfin, Komga, Kavita) indexes.

## Features

- Downloads saved as CBZ archives by default (`DOWNLOAD_AS_CBZ=true`), each with an embedded `ComicInfo.xml` (series, chapter number, title, summary, authors, genres)
- Separate `downloads` volume (existing claim, optional `subPath`, configurable mount path) so a media server can read the chapters
- Optional managed PVC for config (H2 database, extensions, `server.conf`) with `existingClaim` reuse
- HTTP `Ingress` and Gateway API `HTTPRoute` exposure
- `envFrom` support for `Secret` / `ConfigMap` references (login credentials, PostgreSQL settings)
- `startupProbe` sized for the first start, which downloads the web UI and the Chromium runtime
- Every resource gated by `enabled`

## Prerequisites

- Kubernetes 1.19+ (Gateway API CRDs `gateway.networking.k8s.io/v1` if `httpRoute.enabled=true`)
- Helm 3.0+
- A PV provisioner if `persistence.enabled=true` and no `existingClaim` is supplied
- An existing PVC (ReadWriteMany if shared with a media server) if `downloads.enabled=true`

## Installation

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm install suwayomi geekxflood/suwayomi \
  --set enabled=true \
  --set persistence.enabled=true \
  --set downloads.enabled=true \
  --set downloads.existingClaim=my-library-pvc
```

## Download layout

Suwayomi writes chapters to `<downloads root>/mangas/<source>/<title>/<chapter>.cbz` and cover thumbnails to `<downloads root>/thumbnails`. The default `downloads.mountPath` mounts the volume at the `mangas` level:

```txt
<volume>/
└── <source>/
    └── <title>/
        ├── <chapter 1>.cbz
        └── <chapter 2>.cbz
```

That keeps thumbnail images out of the media server's library. To keep the thumbnails on the shared volume too, set `downloads.mountPath` to `/home/suwayomi/.local/share/Tachidesk/downloads`.

## Using the downloads with Jellyfin

Jellyfin 12 reads CBZ archives and `ComicInfo.xml` natively in a library of type **Books**; Jellyfin 10.x needs the Bookshelf plugin. Point a Books library at the same volume. Loose image folders are not indexed, so keep `DOWNLOAD_AS_CBZ=true`.

## Configuration

| Key | Default | Description |
| --- | ------- | ----------- |
| `enabled` | `false` | Render the chart's resources |
| `image.registry` | `ghcr.io` | Image registry |
| `image.repository` | `suwayomi/suwayomi-server` | Image repository |
| `image.tag` | `""` | Image tag, defaults to `appVersion` |
| `env` | `TZ`, `DOWNLOAD_AS_CBZ` | Variables from the [image's list](https://github.com/Suwayomi/Suwayomi-Server-docker#environment-variables); `BIND_IP` and `BIND_PORT` are set by the chart |
| `envFrom` | `[]` | `{type: secret\|configmap, name}` references |
| `service.port` | `4567` | Service and container port |
| `persistence.enabled` | `false` | Persist the config directory |
| `persistence.existingClaim` | `""` | Reuse an existing PVC instead of creating `<fullname>-config` |
| `persistence.size` | `10Gi` | Size of the created PVC |
| `downloads.enabled` | `false` | Mount a volume for downloaded chapters |
| `downloads.existingClaim` | `""` | PVC to mount (required when enabled) |
| `downloads.subPath` | `""` | Sub-directory of the PVC to mount |
| `downloads.mountPath` | `.../Tachidesk/downloads/mangas` | Where the PVC is mounted |
| `httpRoute.enabled` | `false` | Create a Gateway API `HTTPRoute` |
| `ingress.enabled` | `false` | Create an `Ingress` |
| `podSecurityContext` | `{}` | Set `fsGroup: 1000` on block storage; the image runs as uid/gid 1000 |
| `startupProbe` / `livenessProbe` / `readinessProbe` | HTTP `GET /` | Probe overrides |

Settings that are not environment variables, such as automatically downloading new chapters, are set in the web UI and persist in the config volume.

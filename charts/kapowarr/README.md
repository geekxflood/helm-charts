# Kapowarr Helm Chart

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A Helm chart for deploying [Kapowarr](https://github.com/Casvt/Kapowarr) on Kubernetes. Kapowarr is to comics what Sonarr is to TV shows: it organizes your CBR/CBZ library, tracks volumes and issues across publishers, hands off downloads to clients like qBittorrent, and renames/restructures files using configurable formats.

## Overview

If you already operate the *arr stack for video, Kapowarr will feel familiar — same domain-driven library model, same indexer/client integration pattern, same "monitor and grab" loop, but pointed at comic books. This chart deploys the upstream `mrcas/kapowarr` image with the web UI on port `5656`, a config/database PVC, and standard ingress options.

Kapowarr's library paths, download client credentials, and metadata source preferences are configured inside its UI after first launch — the chart exposes the runtime, not the application config.

## Features

- Single-replica Deployment with `Recreate` strategy (RWO config volume)
- HTTP `/` liveness and readiness probes on port `5656`
- Chart-managed config/database PVC via `persistence.*`
- Ingress and Gateway API `HTTPRoute` exposure
- Optional HorizontalPodAutoscaler (off by default — Kapowarr is single-instance)
- ServiceAccount with optional automount

## Prerequisites

- Kubernetes 1.19+ (Gateway API 1.0+ if using `httpRoute`)
- Helm 3.0+
- Persistent storage for the Kapowarr database (`/app/db`), the comics library, and a temporary downloads directory
- A download client (qBittorrent, Transmission, SABnzbd) reachable from the cluster

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install kapowarr geekxflood/kapowarr -f values.yaml
```

The chart defaults to `enabled: false`. Override it in your values file to render resources.

## Configuration

### Core Parameters

| Parameter          | Description                                         | Default          |
| ------------------ | --------------------------------------------------- | ---------------- |
| `enabled`          | Master switch                                       | `false`          |
| `replicaCount`     | Pod replicas (keep at `1`)                          | `1`              |
| `image.repository` | Container image                                     | `mrcas/kapowarr` |
| `image.tag`        | Image tag                                           | `latest`         |
| `image.pullPolicy` | Image pull policy                                   | `Always`         |
| `imagePullSecrets` | Image pull secret references                        | `[]`             |
| `nameOverride`     | Override chart name in resource names               | `""`             |
| `fullnameOverride` | Override full release name in resource names        | `""`             |

### Service Account

| Parameter                    | Description                  | Default |
| ---------------------------- | ---------------------------- | ------- |
| `serviceAccount.create`      | Create a ServiceAccount      | `true`  |
| `serviceAccount.automount`   | Automount the token          | `true`  |
| `serviceAccount.annotations` | Annotations on the SA        | `{}`    |
| `serviceAccount.name`        | Use an existing SA name      | `""`    |

### Pod & Container

| Parameter            | Description                | Default    |
| -------------------- | -------------------------- | ---------- |
| `podAnnotations`     | Pod annotations            | `{}`       |
| `podLabels`          | Pod labels                 | `{}`       |
| `podSecurityContext` | Pod-level security context | `{}`       |
| `securityContext`    | Container security context | `{}`       |
| `env`                | Environment variables (commonly `PUID`, `PGID`, `TZ`) | `[]` |
| `resources`          | Resource requests/limits   | `{}`       |
| `nodeSelector`       | Node selector              | `{}`       |
| `tolerations`        | Pod tolerations            | `[]`       |
| `affinity`           | Pod affinity rules         | `{}`       |
| `strategy.type`      | Deployment strategy        | `Recreate` |

### Service

| Parameter      | Description                | Default     |
| -------------- | -------------------------- | ----------- |
| `service.type` | Service type               | `ClusterIP` |
| `service.port` | Kapowarr web UI port       | `5656`      |

### Ingress

| Parameter             | Description           | Default |
| --------------------- | --------------------- | ------- |
| `ingress.enabled`     | Create an Ingress     | `false` |
| `ingress.className`   | IngressClass name     | `""`    |
| `ingress.annotations` | Ingress annotations   | `{}`    |
| `ingress.hosts`       | Host/path definitions | `[]`    |
| `ingress.tls`         | TLS host/secret pairs | `[]`    |

### Gateway API HTTPRoute

| Parameter               | Description                                | Default |
| ----------------------- | ------------------------------------------ | ------- |
| `httpRoute.enabled`     | Create a Gateway API `HTTPRoute`           | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                      | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                           | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments             | `[]`    |
| `httpRoute.hostnames`   | Matched hostnames                          | `[]`    |
| `httpRoute.rules`       | Route rules (default backend is this Service on `service.port`) | `[]`    |

### Persistence

| Parameter                  | Description                                            | Default                |
| -------------------------- | ------------------------------------------------------ | ---------------------- |
| `persistence.enabled`      | Create a chart-managed PVC for config/db               | `false`                |
| `persistence.name`         | Override PVC name (default `<release>-config-pvc`)     | `""`                   |
| `persistence.storageClass` | StorageClass                                           | `""` (cluster default) |
| `persistence.accessMode`   | PVC access mode                                        | `ReadWriteOnce`        |
| `persistence.size`         | PVC size                                               | `10Gi`                 |
| `persistence.volumeName`   | Bind to a specific PV                                  | `""`                   |
| `volumes`                  | Extra pod volumes (config, comics, downloads)          | `[]`                   |
| `volumeMounts`             | Extra container mounts                                 | `[]`                   |

The chart's PVC is not auto-mounted. Wire it in via `volumes` / `volumeMounts` so you control the in-container path. Kapowarr expects the database at `/app/db` and uses `/app/temp_downloads` as its scratch dir.

### Probes & Autoscaling

| Parameter                  | Description                              | Default               |
| -------------------------- | ---------------------------------------- | --------------------- |
| `livenessProbe`            | HTTP GET `/` on port 5656                | 60s delay, 30s period |
| `readinessProbe`           | HTTP GET `/` on port 5656                | 30s delay, 15s period |
| `autoscaling.enabled`      | Enable HPA (not useful for Kapowarr)     | `false`               |
| `autoscaling.minReplicas`  | HPA min replicas                         | `1`                   |
| `autoscaling.maxReplicas`  | HPA max replicas                         | `100`                 |

## Examples

### Full install with config, comics library, and downloads

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: TZ
    value: "America/New_York"

persistence:
  enabled: true
  size: 10Gi
  storageClass: longhorn

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: kapowarr-config-pvc
  - name: comics
    persistentVolumeClaim:
      claimName: comics-library-pvc
  - name: downloads
    persistentVolumeClaim:
      claimName: downloads-pvc

volumeMounts:
  - name: config
    mountPath: /app/db
  - name: comics
    mountPath: /comics
  - name: downloads
    mountPath: /app/temp_downloads

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: kapowarr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: kapowarr-tls
      hosts:
        - kapowarr.example.com
```

### Behind a Gateway API gateway

```yaml
enabled: true

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - kapowarr.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1

persistence:
  enabled: true
  size: 10Gi

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: kapowarr-config-pvc
  - name: comics
    persistentVolumeClaim:
      claimName: comics-library-pvc
volumeMounts:
  - name: config
    mountPath: /app/db
  - name: comics
    mountPath: /comics
```

## Persistence

Kapowarr typically uses three volumes:

| Mount path             | Purpose                                              | Recommended access mode |
| ---------------------- | ---------------------------------------------------- | ----------------------- |
| `/app/db`              | Kapowarr SQLite database and application config     | `ReadWriteOnce`         |
| `/comics`              | Your comic library (final destination after import) | `ReadWriteMany` (if shared with other apps) |
| `/app/temp_downloads`  | Working directory for in-flight downloads            | `ReadWriteOnce` or RWX  |

Use the chart-managed PVC for `/app/db` and bring your own PVCs (typically NFS- or CephFS-backed) for the library and downloads paths.

## Integration notes

Kapowarr is configured almost entirely through its web UI. After install, port-forward and run through the initial setup:

```bash
kubectl port-forward svc/<release>-kapowarr 5656:5656
```

Then under *Settings*:

- **Download clients** — point Kapowarr at your download client's in-cluster Service, e.g. `http://qbittorrent.downloads.svc.cluster.local:8080`.
- **Indexers** — Kapowarr uses external comics-specific torrent/Usenet indexers; configure them with their public URLs and API keys.
- **Root folders** — set `/comics` (or wherever you mounted your library volume).
- **Mass editor** — once a library scan completes, use this to tag and organize existing comics.

If you back up Kapowarr with the `backuparr` chart, point it at the same `config` PVC via `apps.kapowarr.configPvc`.

## Upgrading

Chart `0.2.0` is the current line. Always snapshot the config PVC (`/app/db`) before bumping `image.tag`, since Kapowarr migrates its SQLite schema in-place on first launch of a new version.

## Support

- Upstream Kapowarr: [github.com/Casvt/Kapowarr](https://github.com/Casvt/Kapowarr)
- Chart issues: [github.com/geekxflood/helm-charts/issues](https://github.com/geekxflood/helm-charts/issues)

## License

This Helm chart is licensed under the Apache License 2.0. Kapowarr is distributed under the GNU GPL v3 — see the [upstream LICENSE](https://github.com/Casvt/Kapowarr/blob/master/LICENSE) for details.

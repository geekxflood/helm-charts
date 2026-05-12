# Cleanuparr Helm Chart

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A Helm chart for deploying [Cleanuparr](https://github.com/flmorg/cleanuparr) on Kubernetes. Cleanuparr automates the housekeeping that the *arr stack does not do on its own: it detects stalled or stuck downloads, removes torrents that have hit their seed-time limits, purges queued items whose download clients have lost track of them, and trims orphaned files left behind after manual operations.

## Overview

Sonarr and Radarr are happy to keep adding to the download queue, but they are conservative about removing things. Cleanuparr fills that gap — it watches your *arr queues and your download client and reconciles them, blocking malicious or low-quality releases, blacklisting bad indexer entries, and stripping out items that will never complete. The web UI on port `11011` lets you tune rules per-app and inspect the cleanup history.

This chart deploys the upstream `ghcr.io/cleanuparr/cleanuparr` image with a config PVC, ingress options, and standard Kubernetes scaffolding. Connections to Sonarr/Radarr/Lidarr/Readarr and to your download clients are configured inside the Cleanuparr UI, not in this chart.

## Features

- Single-replica Deployment with `Recreate` strategy (RWO config volume)
- HTTP `/` liveness and readiness probes on port `11011`
- Chart-managed `/config` PVC via `persistence.*`
- Ingress and Gateway API `HTTPRoute` exposure
- Optional HorizontalPodAutoscaler (off by default — Cleanuparr is single-instance)
- ServiceAccount with optional automount

## Prerequisites

- Kubernetes 1.19+ (Gateway API 1.0+ if using `httpRoute`)
- Helm 3.0+
- A working *arr stack (Sonarr, Radarr, Lidarr, Readarr) reachable from the cluster
- Direct cluster access to your download client(s) — qBittorrent, Transmission, Deluge, SABnzbd, NZBGet
- Persistent storage for `/config` (recommended)

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install cleanuparr geekxflood/cleanuparr -f values.yaml
```

The chart ships with `enabled: false`. Override it in your values file.

## Configuration

### Core Parameters

| Parameter          | Description                                          | Default                          |
| ------------------ | ---------------------------------------------------- | -------------------------------- |
| `enabled`          | Master switch                                        | `false`                          |
| `replicaCount`     | Pod replicas (keep at `1`)                           | `1`                              |
| `image.repository` | Container image                                      | `ghcr.io/cleanuparr/cleanuparr`  |
| `image.tag`        | Image tag                                            | `latest`                         |
| `image.pullPolicy` | Image pull policy                                    | `Always`                         |
| `imagePullSecrets` | Image pull secret references                         | `[]`                             |
| `nameOverride`     | Override chart name in resource names                | `""`                             |
| `fullnameOverride` | Override full release name in resource names         | `""`                             |

### Service Account

| Parameter                    | Description                | Default |
| ---------------------------- | -------------------------- | ------- |
| `serviceAccount.create`      | Create a ServiceAccount    | `true`  |
| `serviceAccount.automount`   | Automount the token        | `true`  |
| `serviceAccount.annotations` | Annotations on the SA      | `{}`    |
| `serviceAccount.name`        | Use an existing SA name    | `""`    |

### Pod & Container

| Parameter            | Description                                              | Default    |
| -------------------- | -------------------------------------------------------- | ---------- |
| `podAnnotations`     | Pod annotations                                          | `{}`       |
| `podLabels`          | Pod labels                                               | `{}`       |
| `podSecurityContext` | Pod-level security context                               | `{}`       |
| `securityContext`    | Container security context                               | `{}`       |
| `env`                | Environment variables (commonly `PUID`, `PGID`, `UMASK`, `TZ`) | `[]` |
| `resources`          | Resource requests/limits                                 | `{}`       |
| `nodeSelector`       | Node selector                                            | `{}`       |
| `tolerations`        | Pod tolerations                                          | `[]`       |
| `affinity`           | Pod affinity rules                                       | `{}`       |
| `strategy.type`      | Deployment strategy                                      | `Recreate` |

### Service

| Parameter      | Description           | Default     |
| -------------- | --------------------- | ----------- |
| `service.type` | Service type          | `ClusterIP` |
| `service.port` | Cleanuparr web UI port | `11011`     |

### Ingress

| Parameter             | Description           | Default |
| --------------------- | --------------------- | ------- |
| `ingress.enabled`     | Create an Ingress     | `false` |
| `ingress.className`   | IngressClass name     | `""`    |
| `ingress.annotations` | Ingress annotations   | `{}`    |
| `ingress.hosts`       | Host/path definitions | `[]`    |
| `ingress.tls`         | TLS host/secret pairs | `[]`    |

### Gateway API HTTPRoute

| Parameter               | Description                                  | Default |
| ----------------------- | -------------------------------------------- | ------- |
| `httpRoute.enabled`     | Create a Gateway API `HTTPRoute`             | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                        | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                             | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments               | `[]`    |
| `httpRoute.hostnames`   | Matched hostnames                            | `[]`    |
| `httpRoute.rules`       | Route rules; omitted `backendRefs` default to this Service | `[]` |

### Persistence

| Parameter                  | Description                                            | Default                |
| -------------------------- | ------------------------------------------------------ | ---------------------- |
| `persistence.enabled`      | Create a chart-managed PVC for `/config`               | `false`                |
| `persistence.name`         | Override PVC name (default `<release>-config-pvc`)     | `""`                   |
| `persistence.storageClass` | StorageClass                                           | `""` (cluster default) |
| `persistence.accessMode`   | PVC access mode                                        | `ReadWriteOnce`        |
| `persistence.size`         | PVC size                                               | `1Gi`                  |
| `persistence.volumeName`   | Bind to a specific PV                                  | `""`                   |
| `volumes`                  | Extra pod volumes                                      | `[]`                   |
| `volumeMounts`             | Extra container mounts                                 | `[]`                   |

The PVC is not auto-mounted; add a matching entry to `volumes`/`volumeMounts`. If Cleanuparr needs visibility into the download directories for orphaned-file cleanup, mount them read-write (or read-only for dry-run).

### Probes & Autoscaling

| Parameter                  | Description                                | Default               |
| -------------------------- | ------------------------------------------ | --------------------- |
| `livenessProbe`            | HTTP GET `/` on port 11011                 | 30s delay, 30s period |
| `readinessProbe`           | HTTP GET `/` on port 11011                 | 15s delay, 15s period |
| `autoscaling.enabled`      | Enable HPA (not useful — single-instance)  | `false`               |
| `autoscaling.minReplicas`  | HPA min replicas                           | `1`                   |
| `autoscaling.maxReplicas`  | HPA max replicas                           | `100`                 |

## Examples

### Install with persistence and access to download directories

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: UMASK
    value: "002"
  - name: TZ
    value: "Europe/Berlin"

persistence:
  enabled: true
  size: 2Gi
  storageClass: longhorn

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: cleanuparr-config-pvc
  - name: downloads
    persistentVolumeClaim:
      claimName: downloads-pvc

volumeMounts:
  - name: config
    mountPath: /config
  - name: downloads
    mountPath: /downloads

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: cleanuparr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: cleanuparr-tls
      hosts:
        - cleanuparr.example.com
```

### Headless install (no UI exposure, just the cleanup engine)

```yaml
enabled: true

persistence:
  enabled: true
  size: 1Gi

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: cleanuparr-config-pvc
volumeMounts:
  - name: config
    mountPath: /config

ingress:
  enabled: false
httpRoute:
  enabled: false
```

Reach the UI when needed with `kubectl port-forward svc/<release>-cleanuparr 11011:11011`.

## Persistence

Cleanuparr persists its rules, schedules, and run history to `/config`. The volume is small (a few hundred MB at most) but it is the source of truth for what cleanup rules apply to each downstream app — back it up alongside your *arr config PVCs.

For orphan-file cleanup, Cleanuparr also needs to *see* the download directory on the filesystem. Mount the same PVC (or NFS share) that your download client writes to, on the same path the *arr apps see it.

## Integration notes

Cleanuparr is configured inside its web UI. After install, port-forward and walk through the setup:

```bash
kubectl port-forward svc/<release>-cleanuparr 11011:11011
```

In *Settings → Apps*, register each *arr app with its in-cluster Service URL and API key:

| App     | Example URL                                       | API key location          |
| ------- | ------------------------------------------------- | ------------------------- |
| Sonarr  | `http://sonarr.media.svc.cluster.local:8989`      | Sonarr → Settings → General |
| Radarr  | `http://radarr.media.svc.cluster.local:7878`      | Radarr → Settings → General |
| Lidarr  | `http://lidarr.media.svc.cluster.local:8686`      | Lidarr → Settings → General |
| Readarr | `http://readarr.media.svc.cluster.local:8787`     | Readarr → Settings → General |

Then register each download client (qBittorrent, Transmission, etc.) using its in-cluster Service URL. Once the apps and clients are wired up, configure the cleanup jobs:

- **Queue Cleaner** — removes stuck/stalled queue items in the *arr apps.
- **Content Blocker** — pre-emptively rejects bad releases using a configurable blocklist.
- **Download Cleaner** — enforces seed-time / ratio rules and cleans up after the download client.

Each job has its own schedule (cron-style) and can be tuned per app.

## Upgrading

Chart `0.2.0` is the current line. Cleanuparr stores all configuration in `/config/config.json` (and related files); back up the PVC before bumping `image.tag`. Upstream release notes: [github.com/flmorg/cleanuparr/releases](https://github.com/flmorg/cleanuparr/releases).

## Support

- Upstream Cleanuparr: [github.com/flmorg/cleanuparr](https://github.com/flmorg/cleanuparr)
- Chart issues: [github.com/geekxflood/helm-charts/issues](https://github.com/geekxflood/helm-charts/issues)

## License

This Helm chart is licensed under the Apache License 2.0. Cleanuparr is distributed under its upstream license; consult the project repository for details.

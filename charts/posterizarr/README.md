# Posterizarr Helm Chart

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

A Helm chart for deploying [Posterizarr](https://github.com/fscorrupt/Posterizarr) on Kubernetes. Posterizarr generates customized poster artwork for movies and shows in your Plex, Jellyfin, or Emby libraries — pulling source images from configured providers, applying overlays, and pushing the result back through your media server's metadata API.

## Overview

Out of the box, media servers pick whatever poster the metadata provider hands them. Posterizarr lets you take control: choose providers per library, apply consistent overlays (4K badges, audio/codec stickers, custom branding), generate language-specific text, and back up the original assets so you can roll back at any time. The web UI on port `8000` exposes job status and configuration.

This chart deploys the upstream `ghcr.io/fscorrupt/posterizarr` image with up to **four distinct persistent volumes** for config, generated assets, asset backups, and manually curated assets — each independently sized and optionally bound to a specific PV.

## Features

- Single-replica Deployment with `Recreate` strategy
- Hardened pod by default (`runAsNonRoot: true`, `runAsUser: 1000`, `runAsGroup: 1000`, `fsGroup: 1000`)
- **Four-tier persistence** for `/config`, `/assets`, `/assetsbackup`, and `/manualassets` — each toggleable independently
- HTTP `/` liveness and readiness probes on port `8000`
- Ingress and Gateway API `HTTPRoute` exposure
- Cloudflare Tunnel (`TunnelBinding`) hooks via `cfTunnel.*` (Kyverno-managed CRDs from `cloudflare-operator`)
- Custom `initContainers` (commonly used to seed `config.json` from a ConfigMap on first launch)
- Custom `command`/`args` not needed — Posterizarr starts a default daemon when `RUN_TIME=disabled`

## Prerequisites

- Kubernetes 1.19+ (Gateway API 1.0+ if using `httpRoute`; Cloudflare TunnelBinding CRD if using `cfTunnel`)
- Helm 3.0+
- Persistent storage for at least `/config` and `/assets` (recommended)
- A running media server (Plex, Jellyfin, or Emby) reachable from the cluster
- Provider API keys (TMDB, Fanart.tv, etc.) — configured inside Posterizarr's `config.json`

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install posterizarr geekxflood/posterizarr -f values.yaml
```

The chart ships with `enabled: false`. Override it in your values file to render resources.

## Configuration

### Core Parameters

| Parameter          | Description                                          | Default                       |
| ------------------ | ---------------------------------------------------- | ----------------------------- |
| `enabled`          | Master switch                                        | `false`                       |
| `replicaCount`     | Pod replicas (keep at `1`)                           | `1`                           |
| `image.repository` | Container image                                      | `ghcr.io/fscorrupt/posterizarr` |
| `image.tag`        | Image tag (`latest` resolves to upstream rolling)    | `latest`                      |
| `image.pullPolicy` | Image pull policy                                    | `Always`                      |
| `imagePullSecrets` | Image pull secret references                         | `[]`                          |
| `nameOverride`     | Override chart name in resource names                | `""`                          |
| `fullnameOverride` | Override full release name in resource names         | `""`                          |

### Service Account

| Parameter                    | Description                | Default |
| ---------------------------- | -------------------------- | ------- |
| `serviceAccount.create`      | Create a ServiceAccount    | `true`  |
| `serviceAccount.automount`   | Automount the token        | `true`  |
| `serviceAccount.annotations` | Annotations on the SA      | `{}`    |
| `serviceAccount.name`        | Use an existing SA name    | `""`    |

### Pod & Container

| Parameter                  | Description                                                                                | Default                                          |
| -------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| `podAnnotations`           | Pod annotations                                                                            | `{}`                                             |
| `podLabels`                | Pod labels                                                                                 | `{}`                                             |
| `podSecurityContext.fsGroup` | Group used to chown mounted volumes                                                      | `1000`                                           |
| `securityContext`          | Container security context (non-root, UID/GID 1000)                                        | `runAsNonRoot: true`, `runAsUser/Group: 1000`    |
| `env`                      | Environment variables                                                                      | `TZ=UTC`, `TERM=xterm`, `RUN_TIME=disabled`      |
| `resources`                | Resource requests/limits                                                                   | `{}`                                             |
| `nodeSelector`             | Node selector                                                                              | `{}`                                             |
| `tolerations`              | Pod tolerations                                                                            | `[]`                                             |
| `affinity`                 | Pod affinity rules                                                                         | `{}`                                             |
| `strategy.type`            | Deployment strategy                                                                        | `Recreate`                                       |
| `initContainers`           | Custom init containers (e.g. seed `config.json` from a ConfigMap)                          | `[]`                                             |

### Service

| Parameter      | Description           | Default     |
| -------------- | --------------------- | ----------- |
| `service.type` | Service type          | `ClusterIP` |
| `service.port` | Posterizarr web UI    | `8000`      |

### Ingress

| Parameter             | Description           | Default |
| --------------------- | --------------------- | ------- |
| `ingress.enabled`     | Create an Ingress     | `false` |
| `ingress.className`   | IngressClass name     | `""`    |
| `ingress.annotations` | Ingress annotations   | `{}`    |
| `ingress.hosts`       | Host/path definitions | `[]`    |
| `ingress.tls`         | TLS host/secret pairs | `[]`    |

### Gateway API HTTPRoute

| Parameter               | Description                                       | Default |
| ----------------------- | ------------------------------------------------- | ------- |
| `httpRoute.enabled`     | Create a Gateway API `HTTPRoute`                  | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                             | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                                  | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments                    | `[]`    |
| `httpRoute.hostnames`   | Matched hostnames                                 | `[]`    |
| `httpRoute.rules`       | Route rules (default backend = this Service)      | `[]`    |

### Cloudflare Tunnel

| Parameter             | Description                                                | Default |
| --------------------- | ---------------------------------------------------------- | ------- |
| `cfTunnel.enabled`    | Create a `TunnelBinding` (requires cloudflare-operator)    | `false` |
| `cfTunnel.tunnelRef`  | Reference to a `ClusterTunnel` / `Tunnel` object           | `{}`    |
| `cfTunnel.subjects`   | Subjects to bind (defaults to this chart's Service)        | `[]`    |

### Persistence (four independent tiers)

Each tier follows the same pattern: `enabled`, `name`, `storageClass`, `accessMode`, `size`, `volumeName`. They are mounted only when their respective `enabled` is `true`.

| Parameter                      | Description                                              | Default              |
| ------------------------------ | -------------------------------------------------------- | -------------------- |
| `persistence.config.enabled`   | PVC for `/config` (application state + `config.json`)    | `false`              |
| `persistence.config.size`      | Config PVC size                                          | `5Gi`                |
| `persistence.assets.enabled`   | PVC for `/assets` (generated posters)                    | `false`              |
| `persistence.assets.size`      | Assets PVC size                                          | `50Gi`               |
| `persistence.assetsbackup.enabled` | PVC for `/assetsbackup` (original artwork backup)    | `false`              |
| `persistence.assetsbackup.size`    | Backup PVC size                                      | `20Gi`               |
| `persistence.manualassets.enabled` | PVC for `/manualassets` (hand-curated artwork)       | `false`              |
| `persistence.manualassets.size`    | Manual-assets PVC size                               | `10Gi`               |
| `volumes`                      | Extra pod volumes (e.g. ConfigMap for `config.json`)     | `[]`                 |
| `volumeMounts`                 | Extra container mounts                                   | `[]`                 |

PVC names default to `<release>-<tier>-pvc` and can be overridden with `persistence.<tier>.name`. Set `volumeName` to bind to a specific PV (useful for migrations and disaster-recovery).

### Probes & Autoscaling

| Parameter             | Description                              | Default               |
| --------------------- | ---------------------------------------- | --------------------- |
| `livenessProbe`       | HTTP GET `/` on port 8000                | 60s delay, 60s period |
| `readinessProbe`      | HTTP GET `/` on port 8000                | 30s delay, 30s period |
| `autoscaling.enabled` | HPA (disabled — Posterizarr is not horizontally scalable) | `false` |

## Examples

### Full install with all four persistence tiers and Ingress

```yaml
enabled: true

env:
  - name: TZ
    value: "Europe/London"
  - name: TERM
    value: "xterm"
  - name: RUN_TIME
    value: "disabled"

persistence:
  config:
    enabled: true
    size: 5Gi
    storageClass: longhorn
  assets:
    enabled: true
    size: 100Gi
    storageClass: longhorn
  assetsbackup:
    enabled: true
    size: 50Gi
    storageClass: longhorn
  manualassets:
    enabled: true
    size: 10Gi
    storageClass: longhorn

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: posterizarr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: posterizarr-tls
      hosts:
        - posterizarr.example.com
```

### Bootstrap config.json from a ConfigMap on first launch

```yaml
enabled: true

persistence:
  config:
    enabled: true
    size: 5Gi
  assets:
    enabled: true
    size: 50Gi

volumes:
  - name: config-init
    configMap:
      name: posterizarr-config-template

initContainers:
  - name: init-config
    image: alpine:3.21
    command: ["/bin/sh", "-c"]
    args:
      - |
        if [ ! -f /config/config.json ]; then
          echo "Seeding default configuration..."
          cp /config-init/config.json /config/config.json
        else
          echo "Existing config.json found, leaving untouched."
        fi
    volumeMounts:
      - name: config
        mountPath: /config
      - name: config-init
        mountPath: /config-init
```

### Cloudflare Tunnel exposure

```yaml
enabled: true

ingress:
  enabled: false

cfTunnel:
  enabled: true
  tunnelRef:
    kind: ClusterTunnel
    name: cloudflare-tunnel
  subjects:
    - name: posterizarr
      spec:
        fqdn: posterizarr.example.com
        protocol: http

persistence:
  config:
    enabled: true
  assets:
    enabled: true
```

## Persistence

Posterizarr separates four concerns onto four volumes — each can be enabled independently, and only the enabled ones are mounted:

| Mount path       | Tier            | What lives here                                                          |
| ---------------- | --------------- | ------------------------------------------------------------------------ |
| `/config`        | `config`        | `config.json`, run logs, queue state                                     |
| `/assets`        | `assets`        | Generated poster output ready to push to your media server               |
| `/assetsbackup`  | `assetsbackup`  | Original poster artwork as fetched from providers, for rollback          |
| `/manualassets`  | `manualassets`  | Hand-curated artwork that overrides automatic generation                 |

The container runs as UID/GID `1000`; the chart sets `fsGroup: 1000` so volumes are chown'd correctly on attach. If you use an external CSI that does not honor `fsGroup` (some NFS provisioners), pre-create the directories with the correct ownership.

## Integration notes

Posterizarr is configured almost entirely through `/config/config.json`. After installing:

1. Port-forward and complete the first-run setup, or seed `config.json` via the init-container pattern shown above.
2. Configure your media server endpoint inside `config.json`. Use in-cluster DNS, for example:
   - Plex: `http://plex.media.svc.cluster.local:32400`
   - Jellyfin: `http://jellyfin.media.svc.cluster.local:8096`
   - Emby: `http://emby.media.svc.cluster.local:8096`
3. Add provider API keys (TMDB, Fanart.tv, TVDB) under the providers section of `config.json`.
4. Use `RUN_TIME=disabled` (the chart default) to let the web UI drive the scheduling; set it to a cron expression to run headless.

When `RUN_TIME=disabled`, the container starts the web UI and waits for manual or UI-scheduled runs.

## Upgrading

Chart `0.2.0` is the current line. Because `image.tag` is pinned to `latest`, Posterizarr will pick up upstream changes on every pod restart — pin to a specific tag for reproducible deployments. Always back up the `assets` and `assetsbackup` PVCs before upstream major version jumps.

## Support

- Upstream Posterizarr: [github.com/fscorrupt/Posterizarr](https://github.com/fscorrupt/Posterizarr)
- Chart issues: [github.com/geekxflood/helm-charts/issues](https://github.com/geekxflood/helm-charts/issues)

## License

This Helm chart is licensed under the Apache License 2.0. Posterizarr is distributed under its upstream license; consult the project repository for details.

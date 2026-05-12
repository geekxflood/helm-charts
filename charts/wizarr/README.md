# Wizarr Helm Chart

![Version: 0.2.1](https://img.shields.io/badge/Version-0.2.1-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 2026.4.0](https://img.shields.io/badge/AppVersion-2026.4.0-informational?style=flat-square)

A Helm chart for deploying [Wizarr](https://wizarr.dev) on Kubernetes. Wizarr is an invitation system for self-hosted media servers — generate a one-time invite link, send it to a friend, and they get auto-onboarded into Plex, Jellyfin, Emby, or Audiobookshelf with the right libraries and permissions, plus an optional guided onboarding flow.

## Overview

Operating a media server for friends and family invariably means manual user provisioning: creating accounts, picking libraries, explaining the apps. Wizarr automates that loop. Admins create invitation links (single-use, time-bounded, or seat-limited); invitees follow the link, sign in (or create an account), and Wizarr calls the right media-server API to grant access. The web UI also handles the "what apps do I install and how do I sign in" walkthrough.

This chart deploys the upstream `ghcr.io/wizarrrr/wizarr` image with the web UI on port `5690`, a data PVC for the SQLite database, and the usual exposure options.

## Features

- Single-replica Deployment with `Recreate` strategy (RWO data volume)
- HTTP `/` liveness and readiness probes on port `5690`
- Chart-managed `/data` PVC via `persistence.*` — automatically mounted into the pod when `persistence.enabled: true`
- Ingress with sensible defaults (host `wizarr.example.local`), Gateway API `HTTPRoute`, and Cloudflare Tunnel (`TunnelBinding`) exposure
- `envFrom` support for pulling configuration from Secrets or ConfigMaps
- Optional HorizontalPodAutoscaler (off by default — Wizarr is a single-instance app)

## Prerequisites

- Kubernetes 1.19+ (Gateway API 1.0+ if using `httpRoute`; cloudflare-operator CRDs if using `cfTunnel`)
- Helm 3.0+
- Persistent storage for `/data` (the SQLite database lives here)
- Admin credentials and API access to your media server(s): Plex token, Jellyfin/Emby API key, Audiobookshelf token

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install wizarr geekxflood/wizarr -f values.yaml
```

The chart defaults to `enabled: false`. You must set it to `true`.

## Configuration

### Core Parameters

| Parameter          | Description                                       | Default                   |
| ------------------ | ------------------------------------------------- | ------------------------- |
| `enabled`          | Master switch                                     | `false`                   |
| `replicaCount`     | Pod replicas (keep at `1`)                        | `1`                       |
| `image.repository` | Container image                                   | `ghcr.io/wizarrrr/wizarr` |
| `image.tag`        | Image tag (overrides `Chart.AppVersion` when set) | `2026.4.0`                |
| `image.pullPolicy` | Image pull policy                                 | `IfNotPresent`            |
| `imagePullSecrets` | Image pull secret references                      | `[]`                      |
| `nameOverride`     | Override chart name in resource names             | `""`                      |
| `fullnameOverride` | Override full release name in resource names      | `""`                      |

### Service Account

| Parameter                    | Description             | Default |
| ---------------------------- | ----------------------- | ------- |
| `serviceAccount.create`      | Create a ServiceAccount | `true`  |
| `serviceAccount.automount`   | Automount the token     | `true`  |
| `serviceAccount.annotations` | Annotations on the SA   | `{}`    |
| `serviceAccount.name`        | Use an existing SA name | `""`    |

### Pod & Container

| Parameter            | Description                                                      | Default                            |
| -------------------- | ---------------------------------------------------------------- | ---------------------------------- |
| `podAnnotations`     | Pod annotations                                                  | `{}`                               |
| `podLabels`          | Pod labels                                                       | `{}`                               |
| `podSecurityContext` | Pod-level security context                                       | `{}`                               |
| `securityContext`    | Container security context                                       | `{}`                               |
| `env`                | Environment variables                                            | `PUID=1000`, `PGID=1000`, `TZ=UTC` |
| `envFrom`            | Pull env from Secrets/ConfigMaps (entries shaped `{type, name}`) | `[]`                               |
| `resources`          | Resource requests/limits                                         | `{}`                               |
| `nodeSelector`       | Node selector                                                    | `{}`                               |
| `tolerations`        | Pod tolerations                                                  | `[]`                               |
| `affinity`           | Pod affinity rules                                               | `{}`                               |
| `strategy.type`      | Deployment strategy                                              | `Recreate`                         |

Use `envFrom` to inject things like `DISABLE_BUILTIN_AUTH` from a ConfigMap when chaining Wizarr behind Authelia or Authentik. The supported shape is:

```yaml
envFrom:
  - type: secret
    name: wizarr-secrets
  - type: configmap
    name: wizarr-config
```

### Service

| Parameter      | Description        | Default     |
| -------------- | ------------------ | ----------- |
| `service.type` | Service type       | `ClusterIP` |
| `service.port` | Wizarr web UI port | `5690`      |

### Ingress

| Parameter             | Description           | Default                                                                                    |
| --------------------- | --------------------- | ------------------------------------------------------------------------------------------ |
| `ingress.enabled`     | Create an Ingress     | `false`                                                                                    |
| `ingress.className`   | IngressClass name     | `""`                                                                                       |
| `ingress.annotations` | Ingress annotations   | `{}`                                                                                       |
| `ingress.hosts`       | Host/path definitions | `[{ host: wizarr.example.local, paths: [{ path: /, pathType: ImplementationSpecific }] }]` |
| `ingress.tls`         | TLS host/secret pairs | `[]`                                                                                       |

Note: unlike most other charts in this repo, `ingress.hosts` ships with a non-empty placeholder. Override it for your real hostname.

### Gateway API HTTPRoute

| Parameter               | Description                                  | Default |
| ----------------------- | -------------------------------------------- | ------- |
| `httpRoute.enabled`     | Create a Gateway API `HTTPRoute`             | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                        | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                             | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments               | `[]`    |
| `httpRoute.hostnames`   | Matched hostnames                            | `[]`    |
| `httpRoute.rules`       | Route rules (default backend = this Service) | `[]`    |

### Cloudflare Tunnel

| Parameter            | Description                                             | Default |
| -------------------- | ------------------------------------------------------- | ------- |
| `cfTunnel.enabled`   | Create a `TunnelBinding` (requires cloudflare-operator) | `false` |
| `cfTunnel.tunnelRef` | Reference to a `ClusterTunnel` / `Tunnel` object        | `{}`    |
| `cfTunnel.subjects`  | Subjects to bind (defaults to this chart's Service)     | `[]`    |

### Persistence

| Parameter                  | Description                                        | Default                |
| -------------------------- | -------------------------------------------------- | ---------------------- |
| `persistence.enabled`      | Create a chart-managed PVC and mount it at `/data` | `false`                |
| `persistence.name`         | Override PVC name (default `<release>-data-pvc`)   | `""`                   |
| `persistence.storageClass` | StorageClass                                       | `""` (cluster default) |
| `persistence.accessMode`   | PVC access mode                                    | `ReadWriteOnce`        |
| `persistence.size`         | PVC size                                           | `5Gi`                  |
| `persistence.volumeName`   | Bind to a specific PV                              | `""`                   |
| `volumes`                  | Extra pod volumes                                  | `[]`                   |
| `volumeMounts`             | Extra container mounts                             | `[]`                   |

Unlike `huntarr`, `kapowarr`, and `cleanuparr`, the Wizarr chart **does** automatically mount the chart-managed PVC at `/data` whenever `persistence.enabled: true`. You do not need to repeat the volume in `volumes`/`volumeMounts`.

### Probes & Autoscaling

| Parameter                 | Description                               | Default               |
| ------------------------- | ----------------------------------------- | --------------------- |
| `livenessProbe`           | HTTP GET `/` on port 5690                 | 60s delay, 30s period |
| `readinessProbe`          | HTTP GET `/` on port 5690                 | 30s delay, 30s period |
| `autoscaling.enabled`     | Enable HPA (not useful — single-instance) | `false`               |
| `autoscaling.minReplicas` | HPA min replicas                          | `1`                   |
| `autoscaling.maxReplicas` | HPA max replicas                          | `100`                 |

## Examples

### Standard install with persistence and Ingress

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: TZ
    value: "America/Los_Angeles"

persistence:
  enabled: true
  size: 5Gi
  storageClass: longhorn

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: invites.example.com
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - secretName: wizarr-tls
      hosts:
        - invites.example.com
```

### Plex + Jellyfin shared deployment behind a Cloudflare Tunnel

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: TZ
    value: "UTC"

envFrom:
  - type: secret
    name: wizarr-server-tokens

persistence:
  enabled: true
  size: 5Gi

ingress:
  enabled: false

cfTunnel:
  enabled: true
  tunnelRef:
    kind: ClusterTunnel
    name: cloudflare-tunnel
  subjects:
    - name: wizarr
      spec:
        fqdn: invites.example.com
        protocol: http
```

Pre-create the Secret with your media-server tokens:

```bash
kubectl create secret generic wizarr-server-tokens \
  --from-literal=PLEX_TOKEN=YOUR_PLEX_TOKEN \
  --from-literal=JELLYFIN_API_KEY=YOUR_JELLYFIN_API_KEY
```

(The actual env-var names Wizarr expects depend on the upstream release — check the [Wizarr docs](https://wizarr.dev) for the variables matching your version.)

## Persistence

Wizarr keeps its database, invitation state, and per-server credentials in `/data` as a SQLite database. Backups are critical: losing this volume means losing every active invitation and configured server. Two options:

1. Set `persistence.enabled: true` and let the chart create + mount a PVC. This is the recommended path.
2. Bring your own PVC via `volumes`/`volumeMounts`, leaving `persistence.enabled: false`. The container expects the data path at `/data`.

For automated nightly backups, the [backuparr](../backuparr/README.md) chart can mount Wizarr's PVC read-only and tar it: set `apps.wizarr.enabled: true` and `apps.wizarr.configPvc: <release>-data-pvc`.

## Integration notes

After install, port-forward and complete the admin setup:

```bash
kubectl port-forward svc/<release>-wizarr 5690:5690
```

Then in _Settings → Media Servers_, add each server using its in-cluster Service DNS:

| Server         | Example URL                                     | Credential |
| -------------- | ----------------------------------------------- | ---------- |
| Plex           | `http://plex.media.svc.cluster.local:32400`     | Plex token |
| Jellyfin       | `http://jellyfin.media.svc.cluster.local:8096`  | API key    |
| Emby           | `http://emby.media.svc.cluster.local:8096`      | API key    |
| Audiobookshelf | `http://audiobookshelf.media.svc.cluster.local` | API token  |

Once a server is registered, invitations from Wizarr will call into that server's API to grant or revoke access. If you front Wizarr with an external auth provider (Authelia, Authentik), set `DISABLE_BUILTIN_AUTH` accordingly in `env` or via `envFrom`.

## Upgrading

Chart `0.2.1` is the current line. `image.tag` is pinned to `2026.4.0` — Wizarr releases use calendar versioning. Always snapshot `/data` (the SQLite DB) before bumping the tag, since migrations run on first start of the new image.

## Support

- Upstream Wizarr: [github.com/wizarrrr/wizarr](https://github.com/wizarrrr/wizarr) — docs at [wizarr.dev](https://wizarr.dev)
- Chart issues: [github.com/geekxflood/helm-charts/issues](https://github.com/geekxflood/helm-charts/issues)

## License

This Helm chart is licensed under the Apache License 2.0. Wizarr is distributed under its upstream license; consult the project repository for details.

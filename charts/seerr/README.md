# Seerr Helm Chart

![Version: 1.1.0](https://img.shields.io/badge/Version-1.1.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: develop](https://img.shields.io/badge/AppVersion-develop-informational?style=flat-square)

A Helm chart for deploying [Seerr](https://docs.seerr.dev) on Kubernetes. Seerr is an open-source media request and discovery manager for **Jellyfin, Plex, and Emby** — a fork of the Overseerr lineage that broadens media server support beyond Plex-only. Users browse a unified catalogue, request new movies and TV shows, and approved requests are forwarded to Sonarr/Radarr for fetching.

This chart deploys the upstream Seerr image (`ghcr.io/seerr-team/seerr`). Pick this chart if your media server is Jellyfin or Emby (or a mixed Jellyfin/Plex household). If you only run Plex, the [`overseerr`](../overseerr) chart in this repository tracks the canonical Overseerr release.

## Features

- Configurable image (registry, repository, pull policy, tag) — defaults to `ghcr.io/seerr-team/seerr:develop`.
- `Recreate` deployment strategy for `ReadWriteOnce` volumes.
- Environment variables via `env` (literal) and `envFrom` (`Secret` / `ConfigMap` references using the chart's `{type, name}` shape).
- HTTP service on port 5055 (Seerr web UI and REST API) with optional `Ingress`.
- Optional Gateway API `HTTPRoute` for vanilla Kubernetes Gateway implementations.
- Optional Cloudflare Tunnel `TunnelBinding` for zero-trust public exposure.
- First-party `persistence` block — chart-managed PVC for `/app/config` with static-binding support via `volumeName` (prevents accidental rebinding and data loss).
- HPA template, configurable resources/probes/scheduling.
- Arbitrary `volumes` / `volumeMounts` in addition to the managed config volume.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- At least one supported media server reachable from the pod: Jellyfin, Plex, or Emby.
- A `StorageClass` for `ReadWriteOnce` PVCs (or pre-provisioned PV for static binding via `persistence.volumeName`).
- An admin account on the chosen media server to complete Seerr's first-time setup wizard.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install seerr geekxflood/seerr
```

### Install with custom values

```bash
helm install seerr geekxflood/seerr -f values.yaml
```

## Configuration

### Global Parameters

| Parameter      | Description                         | Default |
| -------------- | ----------------------------------- | ------- |
| `enabled`      | Enable/disable the chart deployment | `false` |
| `replicaCount` | Number of Seerr replicas            | `1`     |

### Image Parameters

| Parameter          | Description        | Default            |
| ------------------ | ------------------ | ------------------ |
| `image.registry`   | Image registry     | `ghcr.io`          |
| `image.repository` | Image repository   | `seerr-team/seerr` |
| `image.pullPolicy` | Image pull policy  | `Always`           |
| `image.tag`        | Image tag          | `"develop"`        |
| `imagePullSecrets` | Image pull secrets | `[]`               |

> The deployment template concatenates `registry/repository:tag`, so you can swap registries (e.g., to a private mirror) by setting `image.registry` alone.

### Service Account Parameters

| Parameter                    | Description                     | Default |
| ---------------------------- | ------------------------------- | ------- |
| `serviceAccount.create`      | Create service account          | `true`  |
| `serviceAccount.automount`   | Automount service account token | `true`  |
| `serviceAccount.annotations` | Service account annotations     | `{}`    |
| `serviceAccount.name`        | Service account name override   | `""`    |

### Pod Parameters

| Parameter            | Description                | Default    |
| -------------------- | -------------------------- | ---------- |
| `nameOverride`       | Override chart name        | `""`       |
| `fullnameOverride`   | Override full release name | `""`       |
| `podAnnotations`     | Pod annotations            | `{}`       |
| `podLabels`          | Pod labels                 | `{}`       |
| `podSecurityContext` | Pod security context       | `{}`       |
| `securityContext`    | Container security context | `{}`       |
| `strategy.type`      | Deployment strategy        | `Recreate` |

### Environment Variables

| Parameter | Description                                                                    | Default |
| --------- | ------------------------------------------------------------------------------ | ------- |
| `env`     | Literal env vars (`TZ`, `LOG_LEVEL`, `PORT`, ...)                              | `[]`    |
| `envFrom` | Refs to `Secret` (`type: secret`) or `ConfigMap` (`type: configmap`) by `name` | `[]`    |

### Service Parameters

| Parameter      | Description  | Default     |
| -------------- | ------------ | ----------- |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Seerr port   | `5055`      |

### Ingress Parameters

| Parameter             | Description                 | Default                          |
| --------------------- | --------------------------- | -------------------------------- |
| `ingress.enabled`     | Enable Ingress              | `false`                          |
| `ingress.className`   | Ingress class name          | `""`                             |
| `ingress.annotations` | Ingress annotations         | `{}`                             |
| `ingress.hosts`       | Ingress hosts configuration | `seerr.example.local` (override) |
| `ingress.tls`         | Ingress TLS configuration   | `[]`                             |

### HTTPRoute (Gateway API) Parameters

| Parameter               | Description                                            | Default |
| ----------------------- | ------------------------------------------------------ | ------- |
| `httpRoute.enabled`     | Enable Gateway API HTTPRoute                           | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                                  | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                                       | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments (required when enabled) | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                            | `[]`    |
| `httpRoute.rules`       | Route rules; `backendRefs` default to this service     | `[]`    |

### Cloudflare Tunnel Parameters

| Parameter            | Description                       | Default |
| -------------------- | --------------------------------- | ------- |
| `cfTunnel.enabled`   | Enable Cloudflare Tunnel binding  | `false` |
| `cfTunnel.tunnelRef` | Tunnel reference (`name`, `kind`) | `{}`    |
| `cfTunnel.subjects`  | Tunnel subjects                   | `[]`    |

### Persistence Parameters

| Parameter                  | Description                                                | Default         |
| -------------------------- | ---------------------------------------------------------- | --------------- |
| `persistence.enabled`      | Provision and mount the config PVC                         | `false`         |
| `persistence.name`         | PVC name (default `<release>-config-pvc`)                  | `""`            |
| `persistence.storageClass` | Storage class (empty = cluster default)                    | `""`            |
| `persistence.accessMode`   | Access mode                                                | `ReadWriteOnce` |
| `persistence.size`         | Storage request                                            | `10Gi`          |
| `persistence.volumeName`   | Bind to a specific PV (static binding, prevents rebinding) | `""`            |
| `persistence.mountPath`    | Mount path inside the container                            | `/app/config`   |

### Autoscaling Parameters

| Parameter                                       | Description                      | Default |
| ----------------------------------------------- | -------------------------------- | ------- |
| `autoscaling.enabled`                           | Enable horizontal pod autoscaler | `false` |
| `autoscaling.minReplicas`                       | Minimum replicas                 | `1`     |
| `autoscaling.maxReplicas`                       | Maximum replicas                 | `100`   |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU utilization           | `80`    |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization        | `80`    |

### Storage & Scheduling

| Parameter      | Description                                | Default |
| -------------- | ------------------------------------------ | ------- |
| `volumes`      | Additional volumes (in addition to config) | `[]`    |
| `volumeMounts` | Additional volume mounts                   | `[]`    |
| `resources`    | Resource requests and limits               | `{}`    |
| `nodeSelector` | Node selector                              | `{}`    |
| `tolerations`  | Tolerations                                | `[]`    |
| `affinity`     | Affinity rules                             | `{}`    |

## Examples

### Jellyfin household with persistence and Ingress

```yaml
enabled: true

env:
  - name: TZ
    value: "Europe/Paris"
  - name: LOG_LEVEL
    value: "info"

persistence:
  enabled: true
  size: 2Gi
  storageClass: standard
  accessMode: ReadWriteOnce
  mountPath: /app/config

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: seerr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: seerr-tls
      hosts:
        - seerr.example.com
```

Then run the first-time setup wizard, choose **Jellyfin** as the media server, and point Seerr at `http://jellyfin.media.svc.cluster.local:8096` if Jellyfin runs in-cluster.

### Plex with secret-backed env and static PV binding

Static binding (`persistence.volumeName`) protects you from the classic StatefulSet/PVC-rebinding footgun: if the PVC is ever deleted (e.g., by a sloppy `helm uninstall --cascade`), recreating it without `volumeName` would re-bind to a _new_ PV, silently losing the database.

```yaml
enabled: true

envFrom:
  - type: secret
    name: seerr-secrets        # provides API keys / SMTP creds, etc.

env:
  - name: TZ
    value: "UTC"

persistence:
  enabled: true
  size: 5Gi
  storageClass: longhorn
  volumeName: pvc-seerr-config-fixed   # pre-provisioned PV, retain reclaim policy

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: seerr.example.com
      paths:
        - path: /
          pathType: Prefix
```

Get the current PV name with:

```bash
kubectl get pvc <release>-config-pvc -o jsonpath='{.spec.volumeName}'
```

### Gateway API HTTPRoute (Cilium) and Cloudflare Tunnel

```yaml
enabled: true

ingress:
  enabled: false

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
  hostnames:
    - seerr.example.com
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
    name: my-cf-tunnel
    kind: ClusterTunnel
  subjects:
    - name: seerr
      spec:
        fqdn: seerr.public.example.com

persistence:
  enabled: true
  size: 2Gi
```

## Persistence

Seerr writes its state to `/app/config`:

- `/app/config/db/db.sqlite3` — application database (users, requests, settings, media server credentials).
- `/app/config/settings.json` — server configuration written by the setup wizard.
- `/app/config/logs/` — application logs.

Enable `persistence.enabled: true` to let the chart provision the PVC for you (named `<release>-config-pvc` unless overridden). Set `persistence.volumeName` to bind to a specific pre-provisioned PV — strongly recommended for production to prevent rebinding accidents.

The default `strategy.type: Recreate` is set so `ReadWriteOnce` volumes detach cleanly between rollouts.

## Integration notes

### Jellyfin

In the setup wizard or **Settings -> Jellyfin**:

- Hostname: `jellyfin.<namespace>.svc.cluster.local`
- Port: `8096`
- Use SSL: `false` (inside the cluster)
- Admin username + password: a Jellyfin admin account
- Email: Seerr will sync Jellyfin users (those without an email use a fallback)

### Plex

Use the Plex sign-in flow under **Settings -> Plex**; Seerr discovers servers attached to the signed-in account. For in-cluster Plex, override the discovered hostname to the service DNS (e.g., `plex.media.svc.cluster.local:32400`).

### Emby

Configure the API key under **Settings -> Emby**:

- Hostname: `emby.<namespace>.svc.cluster.local`
- Port: `8096`
- API Key: from Emby **Dashboard -> Advanced -> API Keys**

### Sonarr / Radarr

Under **Settings -> Services**, add each *arr instance with its in-cluster service DNS, port (`8989` / `7878`), and API key. Pick the default quality profile and root folder.

## Upgrading

### To 1.1.0

- Documentation refresh; behaviour unchanged.

### To 1.0.0

- First stable chart release after the Seerr fork stabilized its image at `ghcr.io/seerr-team/seerr`.

Before upgrading Seerr itself across major versions, back up `/app/config/db/db.sqlite3` — schema migrations are forward-only.

## Uninstallation

```bash
helm uninstall seerr
```

If `persistence.enabled` was `true`, the PVC is retained by Helm only if you didn't set its annotation to `helm.sh/resource-policy: keep`. Delete it explicitly if you want to reclaim the storage:

```bash
kubectl delete pvc <release>-config-pvc
```

## Support

- Seerr docs: <https://docs.seerr.dev>
- Seerr source: <https://github.com/seerr-team/seerr>
- Chart Repository Issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. Seerr is open-source software; see the upstream repository for its license terms.

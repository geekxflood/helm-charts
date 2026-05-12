# Overseerr Helm Chart

![Version: 0.3.1](https://img.shields.io/badge/Version-0.3.1-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.35.0](https://img.shields.io/badge/AppVersion-1.35.0-informational?style=flat-square)

A Helm chart for deploying [Overseerr](https://overseerr.dev) on Kubernetes. Overseerr is the original request and discovery manager for Plex — it gives end users a Plex-style browse experience for movies and TV, lets them request new content, and forwards approved requests to Sonarr/Radarr for fetching. It authenticates users against your Plex server, so the people who already use your Plex library can request straight away.

This chart deploys the [LinuxServer.io Overseerr image](https://hub.docker.com/r/linuxserver/overseerr). Overseerr is **Plex-only** by design; if you need Jellyfin or Emby support, see the [`seerr`](../seerr) chart in this repository.

## Features

- Configurable image, replicas, resources, and pod metadata.
- `Recreate` deployment strategy by default — required for `ReadWriteOnce` persistent volumes.
- Environment variables via `env` (literal) and `envFrom` (`Secret` / `ConfigMap` references using the chart's `{type, name}` shape).
- Pluggable `runtimeClassName` via `runtime.enabled` + `runtime.name`.
- HTTP service on port 5055 (Overseerr web UI and REST API) with optional `Ingress`.
- Optional Gateway API `HTTPRoute` for vanilla Kubernetes Gateway implementations.
- Optional Cloudflare Tunnel `TunnelBinding` for zero-trust public exposure.
- HPA template for horizontal autoscaling.
- Arbitrary `volumes` / `volumeMounts` — bring your own PVC for `/config`.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- A running Plex Media Server reachable from the pod (over LAN, in-cluster, or the public Internet).
- A `StorageClass` capable of provisioning `ReadWriteOnce` volumes for `/config`.
- A Plex account that owns or has access to the target Plex server (used during the first-time setup wizard).

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install overseerr geekxflood/overseerr
```

### Install with custom values

```bash
helm install overseerr geekxflood/overseerr -f values.yaml
```

## Configuration

### Global Parameters

| Parameter      | Description                         | Default |
| -------------- | ----------------------------------- | ------- |
| `enabled`      | Enable/disable the chart deployment | `false` |
| `replicaCount` | Number of Overseerr replicas        | `1`     |

### Image Parameters

| Parameter          | Description        | Default                 |
| ------------------ | ------------------ | ----------------------- |
| `image.repository` | Image repository   | `linuxserver/overseerr` |
| `image.pullPolicy` | Image pull policy  | `IfNotPresent`          |
| `image.tag`        | Image tag          | `"1.35.0"`              |
| `imagePullSecrets` | Image pull secrets | `[]`                    |

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

### Runtime Class

| Parameter         | Description                         | Default |
| ----------------- | ----------------------------------- | ------- |
| `runtime.enabled` | Set `runtimeClassName` on the pod   | `false` |
| `runtime.name`    | Runtime class name (e.g., `gvisor`) | `""`    |

### Environment Variables

| Parameter | Description                                               | Default |
| --------- | --------------------------------------------------------- | ------- |
| `env`     | Literal env vars (`PUID`, `PGID`, `TZ`, `LOG_LEVEL`, ...) | `[]`    |
| `envFrom` | Refs to `Secret` / `ConfigMap` by `type` and `name`       | `[]`    |

### Service Parameters

| Parameter      | Description    | Default     |
| -------------- | -------------- | ----------- |
| `service.type` | Service type   | `ClusterIP` |
| `service.port` | Overseerr port | `5055`      |

### Ingress Parameters

| Parameter             | Description                 | Default                          |
| --------------------- | --------------------------- | -------------------------------- |
| `ingress.enabled`     | Enable Ingress              | `false`                          |
| `ingress.className`   | Ingress class name          | `""`                             |
| `ingress.annotations` | Ingress annotations         | `{}`                             |
| `ingress.hosts`       | Ingress hosts configuration | `chart-example.local` (override) |
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
| `cfTunnel.subjects`  | Tunnel subjects                   | `{}`    |

### Autoscaling Parameters

| Parameter                                       | Description                      | Default |
| ----------------------------------------------- | -------------------------------- | ------- |
| `autoscaling.enabled`                           | Enable horizontal pod autoscaler | `false` |
| `autoscaling.minReplicas`                       | Minimum replicas                 | `1`     |
| `autoscaling.maxReplicas`                       | Maximum replicas                 | `100`   |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU utilization           | `80`    |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization        | `80`    |

### Storage & Scheduling

| Parameter      | Description                  | Default |
| -------------- | ---------------------------- | ------- |
| `volumes`      | Additional volumes           | `[]`    |
| `volumeMounts` | Additional volume mounts     | `[]`    |
| `resources`    | Resource requests and limits | `{}`    |
| `nodeSelector` | Node selector                | `{}`    |
| `tolerations`  | Tolerations                  | `[]`    |
| `affinity`     | Affinity rules               | `{}`    |

## Examples

### Basic install with persistence and Ingress

Create the config PVC first (the chart does not manage it):

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: overseerr-config
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Gi
EOF
```

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "100"
  - name: TZ
    value: "Europe/Paris"
  - name: LOG_LEVEL
    value: "info"

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: overseerr-config

volumeMounts:
  - name: config
    mountPath: /config

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: overseerr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: overseerr-tls
      hosts:
        - overseerr.example.com
```

After the pod is ready, browse to `https://overseerr.example.com` and step through the setup wizard:

1. Sign in with the Plex account that owns your Plex server.
2. Connect to your Plex server (Overseerr probes it via the Plex API).
3. Add Sonarr and Radarr connections so approved requests can be auto-forwarded.

### Connecting to in-cluster Plex via service DNS

If Plex runs in the same cluster, point Overseerr at it via service DNS instead of the public hostname — keeps API tokens off the wire:

```yaml
enabled: true

env:
  - name: TZ
    value: "UTC"

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: overseerr-config

volumeMounts:
  - name: config
    mountPath: /config
```

Then in the Overseerr wizard, enter the Plex hostname as `plex.media.svc.cluster.local` and port `32400` (no TLS needed inside the cluster).

### Gateway API HTTPRoute

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
    - overseerr.example.com
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
      claimName: overseerr-config

volumeMounts:
  - name: config
    mountPath: /config
```

## Persistence

Overseerr stores its state at `/config`:

- `/config/db/db.sqlite3` — application database (users, requests, settings, Plex/Sonarr/Radarr credentials).
- `/config/settings.json` — server configuration written by the setup wizard.
- `/config/logs/` — application logs.

The chart does not declare a built-in persistence block — provide a PVC through `volumes` / `volumeMounts` and mount it at `/config`. The default `strategy.type: Recreate` is set specifically so `ReadWriteOnce` volumes can detach and re-attach cleanly during rollouts.

## Integration notes

### Sonarr / Radarr

In Overseerr **Settings -> Services**, add each *arr instance:

- Hostname: in-cluster DNS, e.g. `sonarr.media.svc.cluster.local`
- Port: `8989` (Sonarr) / `7878` (Radarr)
- API key: from the *arr **Settings -> General** page
- Default quality / root folder: pre-configured profile in the *arr app
- Enable as 4K server: optional, if you run a parallel *arr instance for 4K

### Plex

Overseerr's setup wizard discovers Plex via the Plex account chosen at first login. After setup, you can re-validate the connection at **Settings -> Plex**. Requesting users sign in via the same Plex account — Overseerr never holds their passwords.

### Webhooks

Overseerr emits webhooks for request status changes (Discord, Slack, generic JSON). Configure them under **Settings -> Notifications**.

## Upgrading

### To 0.3.1

- Documentation refresh; behaviour unchanged.

### To 0.3.0

- Added Gateway API `HTTPRoute` and Cloudflare Tunnel `TunnelBinding` templates.

When upgrading across major Overseerr versions, always back up `/config/db/db.sqlite3` first — Overseerr migrates the schema on startup and the migration is forward-only.

## Uninstallation

```bash
helm uninstall overseerr
```

PVCs are not deleted automatically. Remove them explicitly if you want the data gone:

```bash
kubectl delete pvc overseerr-config
```

## Support

- Overseerr docs: <https://docs.overseerr.dev>
- Overseerr source: <https://github.com/sct/overseerr>
- LinuxServer.io image: <https://hub.docker.com/r/linuxserver/overseerr>
- Chart Repository Issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. Overseerr is licensed under the [MIT License](https://github.com/sct/overseerr/blob/develop/LICENSE).

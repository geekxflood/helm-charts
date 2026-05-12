# Bazarr Helm Chart

![Version: 0.6.0](https://img.shields.io/badge/Version-0.6.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.5.2](https://img.shields.io/badge/AppVersion-1.5.2-informational?style=flat-square)

[Bazarr](https://www.bazarr.media/) is a companion to Radarr and Sonarr that finds, downloads, and renames subtitles for your existing movie and TV libraries. It hooks into Radarr/Sonarr over their APIs to learn what's in your library, then queries OpenSubtitles, Subscene, Addic7ed, and a dozen other providers — with per-language profiles and per-show overrides. This chart runs Bazarr on Kubernetes using the [LinuxServer.io image](https://hub.docker.com/r/linuxserver/bazarr) and exposes it via Ingress, Gateway API HTTPRoute, or Cloudflare Tunnel.

Bazarr is **not** a standalone library manager. It will not work usefully unless you also run Radarr and/or Sonarr and give Bazarr access to the same media volumes.

## Features

- `Deployment` with `Recreate` strategy by default — suits the `ReadWriteOnce` config volume that holds Bazarr's SQLite DB.
- `ClusterIP` service on port `6767`.
- Three exposure paths: classic `Ingress`, Gateway API `HTTPRoute` (`gateway.networking.k8s.io/v1`), Cloudflare `TunnelBinding` (`networking.cfargotunnel.com/v1alpha1`).
- Probes hit `/` on port 6767.
- Optional `PersistentVolumeClaim` for `/config` via the same `persistence.*` pattern as the other charts. Note: the `persistence` block is intentionally omitted from `values.yaml` defaults — set it explicitly to render the PVC. See the example below.
- HPA scaffolding included; keep `replicaCount: 1` — Bazarr is single-writer.

This chart does **not** ship the OpenBao API-key sync init container present on Radarr/Sonarr/Readarr. Bazarr authenticates **outward** to Radarr/Sonarr; it doesn't need its own key syndicated.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- Running Radarr and/or Sonarr instances reachable from the pod (in-cluster service DNS works fine).
- The same `/movies` and `/tv` volumes that Radarr/Sonarr use, mounted at identical paths inside Bazarr — Bazarr writes `.srt` files next to the video files.
- Optional:
  - [Gateway API CRDs](https://gateway-api.sigs.k8s.io/) for `httpRoute`.
  - [cloudflare-operator](https://github.com/adyanth/cloudflare-operator) for `cfTunnel`.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install

```bash
helm install bazarr geekxflood/bazarr
helm install bazarr geekxflood/bazarr -f values.yaml
```

Bazarr ships with `enabled: false`. Set `enabled: true` to render workloads.

## Configuration

### Global

| Parameter          | Description                          | Default    |
| ------------------ | ------------------------------------ | ---------- |
| `enabled`          | Master switch                        | `false`    |
| `replicaCount`     | Pod count (keep `1`)                 | `1`        |
| `nameOverride`     | Override the chart name in resources | `""`       |
| `fullnameOverride` | Override the fully qualified name    | `""`       |
| `strategy.type`    | Deployment strategy                  | `Recreate` |

### Image

| Parameter          | Description                                  | Default              |
| ------------------ | -------------------------------------------- | -------------------- |
| `image.repository` | Container image                              | `linuxserver/bazarr` |
| `image.tag`        | Image tag (falls back to `Chart.appVersion`) | `"latest"`           |
| `image.pullPolicy` | Image pull policy                            | `Always`             |
| `imagePullSecrets` | Pull secrets list                            | `[]`                 |

### Pod & Service Account

| Parameter                    | Description                  | Default |
| ---------------------------- | ---------------------------- | ------- |
| `serviceAccount.create`      | Create a dedicated SA        | `true`  |
| `serviceAccount.automount`   | Auto-mount SA token          | `true`  |
| `serviceAccount.annotations` | SA annotations               | `{}`    |
| `serviceAccount.name`        | Override SA name             | `""`    |
| `podAnnotations`             | Pod annotations              | `{}`    |
| `podLabels`                  | Pod labels                   | `{}`    |
| `podSecurityContext`         | Pod-level security context   | `{}`    |
| `securityContext`            | Container security context   | `{}`    |
| `env`                        | Container env vars           | `[]`    |

### Service

| Parameter      | Description              | Default     |
| -------------- | ------------------------ | ----------- |
| `service.type` | Kubernetes service type  | `ClusterIP` |
| `service.port` | Service & container port | `6767`      |

### Ingress

| Parameter             | Description         | Default |
| --------------------- | ------------------- | ------- |
| `ingress.enabled`     | Render an `Ingress` | `false` |
| `ingress.className`   | `ingressClassName`  | `""`    |
| `ingress.annotations` | Ingress annotations | `{}`    |
| `ingress.hosts`       | List of host/paths  | `[]`    |
| `ingress.tls`         | TLS secret refs     | `[]`    |

### HTTPRoute (Gateway API)

| Parameter               | Description                                                | Default |
| ----------------------- | ---------------------------------------------------------- | ------- |
| `httpRoute.enabled`     | Render an `HTTPRoute`                                      | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                                      | `{}`    |
| `httpRoute.labels`      | Additional labels                                          | `{}`    |
| `httpRoute.parentRefs`  | Gateways/listeners this route attaches to (required)       | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                                | `[]`    |
| `httpRoute.rules`       | List of `matches` / `filters` / `backendRefs` / `timeouts` | `[]`    |

### Cloudflare Tunnel

| Parameter            | Description                              | Default |
| -------------------- | ---------------------------------------- | ------- |
| `cfTunnel.enabled`   | Render a `TunnelBinding`                 | `false` |
| `cfTunnel.tunnelRef` | Reference to a `ClusterTunnel`/`Tunnel`  | `{}`    |
| `cfTunnel.subjects`  | Tunnel subjects (defaults to the service) | `[]`   |

### Persistence (`/config`)

The `persistence` key is not present in `values.yaml`; the PVC template (`templates/pvc.yaml`) only renders when you set `persistence.enabled: true`. Defaults below apply once you opt in.

| Parameter                  | Description                                              | Default                |
| -------------------------- | -------------------------------------------------------- | ---------------------- |
| `persistence.enabled`      | Render the config PVC                                    | `false` (unset)        |
| `persistence.name`         | PVC name override (default `<release>-config-iscsi-pvc`) | `""`                   |
| `persistence.storageClass` | Storage class                                            | `""` (cluster default) |
| `persistence.accessMode`   | PVC access mode                                          | `ReadWriteOnce`        |
| `persistence.size`         | Requested storage                                        | `50Gi`                 |
| `persistence.volumeName`   | Bind to a specific `PersistentVolume`                    | `""`                   |

### Volumes / Volume Mounts

| Parameter      | Description                         | Default |
| -------------- | ----------------------------------- | ------- |
| `volumes`      | Additional `pod.spec.volumes`       | `[]`    |
| `volumeMounts` | Additional `container.volumeMounts` | `[]`    |

### Probes

| Parameter        | Description                         | Default                        |
| ---------------- | ----------------------------------- | ------------------------------ |
| `livenessProbe`  | Liveness probe (HTTP GET `/`:6767)  | `initialDelay 60s, period 60s` |
| `readinessProbe` | Readiness probe (HTTP GET `/`:6767) | `initialDelay 30s, period 30s` |

### Resources & Scheduling

| Parameter      | Description                    | Default |
| -------------- | ------------------------------ | ------- |
| `resources`    | CPU / memory requests & limits | `{}`    |
| `nodeSelector` | `pod.spec.nodeSelector`        | `{}`    |
| `tolerations`  | `pod.spec.tolerations`         | `[]`    |
| `affinity`     | `pod.spec.affinity`            | `{}`    |

### Autoscaling (HPA)

| Parameter                                       | Description   | Default |
| ----------------------------------------------- | ------------- | ------- |
| `autoscaling.enabled`                           | Render an HPA | `false` |
| `autoscaling.minReplicas`                       | Min replicas  | `1`     |
| `autoscaling.maxReplicas`                       | Max replicas  | `100`   |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU    | `80`    |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory | `80`    |

## Examples

### Basic install alongside Radarr & Sonarr

The critical part is that `/movies` and `/tv` must be the **same volumes** Radarr/Sonarr mount — Bazarr writes subtitle files next to each video.

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: TZ
    value: "Europe/Paris"

persistence:
  enabled: true
  size: 5Gi
  storageClass: longhorn

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: bazarr-config-iscsi-pvc
  - name: movies
    persistentVolumeClaim:
      claimName: media-movies      # same PVC Radarr mounts
  - name: tv
    persistentVolumeClaim:
      claimName: media-tv          # same PVC Sonarr mounts

volumeMounts:
  - name: config
    mountPath: /config
  - name: movies
    mountPath: /movies
  - name: tv
    mountPath: /tv

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: bazarr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - bazarr.example.com
      secretName: bazarr-tls
```

After install, open Bazarr → `Settings → Sonarr` and `Settings → Radarr` and paste:

- **Address**: `radarr.media.svc.cluster.local` / `sonarr.media.svc.cluster.local`
- **Port**: `7878` / `8989`
- **API key**: from each app's `Settings → General`.

### HTTPRoute + Cloudflare Tunnel

```yaml
enabled: true

ingress:
  enabled: false

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - bazarr.example.com
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
    kind: ClusterTunnel
    name: prod-tunnel
```

CLI equivalent for a minimal Ingress install:

```bash
helm install bazarr geekxflood/bazarr \
  --set enabled=true \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set 'ingress.hosts[0].host=bazarr.example.com' \
  --set 'ingress.hosts[0].paths[0].path=/' \
  --set 'ingress.hosts[0].paths[0].pathType=Prefix'
```

## Persistence

| Mount     | Purpose                                            | Provided by chart?           |
| --------- | -------------------------------------------------- | ---------------------------- |
| `/config` | Bazarr SQLite DB, provider credentials, profiles   | Yes, via `persistence.*`     |
| `/movies` | Read/write access to Radarr's library              | No, share Radarr's PVC       |
| `/tv`     | Read/write access to Sonarr's library              | No, share Sonarr's PVC       |

Bazarr must be able to **write** alongside video files (to drop `.srt` next to `Movie.mkv`). `/movies` and `/tv` should be `ReadWriteMany` so they can be mounted by Radarr/Sonarr and Bazarr simultaneously.

## Integration notes

- **Bazarr → Radarr**: Bazarr reads Radarr's library and download history over its REST API. URL pattern: `http://<radarr-release>.<namespace>.svc:7878`. API key lives in Radarr's `Settings → General`.
- **Bazarr → Sonarr**: same pattern, port `8989`.
- **Bazarr → Lingarr**: if you also deploy the [lingarr chart](../lingarr), point Lingarr at this Bazarr instance. Lingarr will then pick up Bazarr's downloaded subtitles and translate them with LLMs.
- **Bazarr does not talk to Prowlarr.** Indexers don't apply to subtitles.

## Upgrading

If a previous release used `persistence.enabled: true`, set `persistence.volumeName` on upgrade to bind the same PV and keep your provider credentials.

## Support

- Upstream: <https://www.bazarr.media/> · [GitHub](https://github.com/morpheus65535/bazarr)
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. Bazarr is licensed under [GPL-3.0](https://github.com/morpheus65535/bazarr/blob/master/LICENSE).

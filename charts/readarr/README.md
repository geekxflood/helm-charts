# Readarr Helm Chart

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 0.4.4.2686](https://img.shields.io/badge/AppVersion-0.4.4.2686-informational?style=flat-square)

[Readarr](https://readarr.com/) is the *arr-stack manager for books and audiobooks. It monitors authors and series, watches indexers (via Prowlarr) for new releases, dispatches downloads to your client, and renames/imports completed files into your library. This chart runs Readarr on Kubernetes with the [LinuxServer.io image](https://hub.docker.com/r/linuxserver/readarr) (development branch — Readarr has no stable release yet), and exposes the UI via Ingress, Gateway API HTTPRoute, or Cloudflare Tunnel.

Use Readarr for ebooks and audiobooks via Usenet/torrents. For an alternative that also scrapes direct download sites and handles magazine subscriptions, see the [lazylibrarian chart](../lazylibrarian).

## Features

- `Deployment` with `Recreate` strategy — required for the `ReadWriteOnce` `/config` PVC.
- Optional static-binding `PersistentVolumeClaim` for `/config` (50 GiB default).
- `ClusterIP` service on port `8787`.
- Three exposure modes: `Ingress`, Gateway API `HTTPRoute`, Cloudflare `TunnelBinding`.
- Probes hit `/ping` — Readarr's lightweight API health endpoint.
- Optional init containers that extract the Readarr API key from `config.xml` and write it to OpenBao/Vault KV v2 via Kubernetes auth.
- HPA scaffolding included; do not enable in practice — single-writer SQLite.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- A `StorageClass` supporting `ReadWriteOnce` for `/config`.
- Out-of-band volumes for `/books`, `/audiobooks`, and `/downloads`.
- Optional:
  - [Gateway API CRDs](https://gateway-api.sigs.k8s.io/) if using `httpRoute`.
  - [cloudflare-operator](https://github.com/adyanth/cloudflare-operator) if using `cfTunnel`.
  - OpenBao/Vault with Kubernetes auth for `openbao`.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install

```bash
helm install readarr geekxflood/readarr
helm install readarr geekxflood/readarr -f values.yaml
```

Readarr ships with `enabled: false`. Set `enabled: true` to render workloads.

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

| Parameter          | Description                                  | Default               |
| ------------------ | -------------------------------------------- | --------------------- |
| `image.repository` | Container image                              | `linuxserver/readarr` |
| `image.tag`        | Image tag (falls back to `Chart.appVersion`) | `"latest"`            |
| `image.pullPolicy` | Image pull policy                            | `Always`              |
| `imagePullSecrets` | Pull secrets list                            | `[]`                  |

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
| `service.port` | Service & container port | `8787`      |

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

| Parameter                  | Description                                              | Default                |
| -------------------------- | -------------------------------------------------------- | ---------------------- |
| `persistence.enabled`      | Render the config PVC                                    | `false`                |
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

| Parameter        | Description                             | Default                        |
| ---------------- | --------------------------------------- | ------------------------------ |
| `livenessProbe`  | Liveness probe (HTTP GET `/ping`:8787)  | `initialDelay 60s, period 60s` |
| `readinessProbe` | Readiness probe (HTTP GET `/ping`:8787) | `initialDelay 30s, period 30s` |

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

### OpenBao API-Key Sync

| Parameter                       | Description                              | Default                               |
| ------------------------------- | ---------------------------------------- | ------------------------------------- |
| `openbao.enabled`               | Run wait + API-key sync init containers  | `false`                               |
| `openbao.address`               | OpenBao/Vault HTTP address               | `""`                                  |
| `openbao.authMount`             | Kubernetes auth mount                    | `kubernetes`                          |
| `openbao.role`                  | OpenBao Kubernetes auth role             | `""`                                  |
| `openbao.kvPath`                | KV v2 destination path                   | `""`                                  |
| `openbao.serviceUrl`            | Cluster URL stored alongside the API key | `""`                                  |
| `openbao.initContainer.image`   | Image used to wait for `config.xml`      | `ghcr.io/apteno/alpine-jq:2024-03-14` |
| `openbao.vaultImage.repository` | Vault CLI image                          | `hashicorp/vault`                     |
| `openbao.vaultImage.tag`        | Vault CLI tag                            | `1.18`                                |

The init containers wait for `/config/config.xml`, grep the `<ApiKey>` element, log into OpenBao using the pod's SA JWT, and write `api_key` and `url` to `openbao.kvPath`.

## Examples

### Basic install with Ingress

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: TZ
    value: "UTC"

persistence:
  enabled: true
  size: 10Gi
  storageClass: longhorn

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: readarr-config-iscsi-pvc
  - name: books
    persistentVolumeClaim:
      claimName: media-books
  - name: audiobooks
    persistentVolumeClaim:
      claimName: media-audiobooks
  - name: downloads
    persistentVolumeClaim:
      claimName: media-downloads

volumeMounts:
  - name: config
    mountPath: /config
  - name: books
    mountPath: /books
  - name: audiobooks
    mountPath: /audiobooks
  - name: downloads
    mountPath: /downloads

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: readarr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - readarr.example.com
      secretName: readarr-tls
```

### HTTPRoute + OpenBao

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
    - readarr.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1

openbao:
  enabled: true
  address: https://openbao.openbao.svc.cluster.local:8200
  authMount: kubernetes
  role: media
  kvPath: secret/data/media/readarr
  serviceUrl: http://readarr.media.svc.cluster.local:8787
```

## Persistence

| Mount         | Purpose                                       | Provided by chart?       |
| ------------- | --------------------------------------------- | ------------------------ |
| `/config`     | SQLite DB, author/metadata cache, profiles    | Yes, via `persistence.*` |
| `/books`      | Ebook library                                 | No, bring your own PVC   |
| `/audiobooks` | Audiobook library                             | No, bring your own PVC   |
| `/downloads`  | Download client output                        | No, bring your own PVC   |

Use `ReadWriteMany` for the library and download volumes when sharing with download clients or other apps.

## Integration notes

- **Prowlarr → Readarr**: in Prowlarr, add Readarr as an app at `http://<readarr-release>.<namespace>.svc:8787` using Readarr's API key. Prowlarr will sync indexer definitions automatically.
- **Download client**: Readarr expects an SABnzbd or qBittorrent endpoint reachable from inside the cluster (`http://sabnzbd.media.svc:8080`, etc.). Share `/downloads` with the download client and Readarr so post-processing can import without copying files.
- **Calibre integration**: Readarr can call out to a Calibre content server for metadata and library import; configure it under `Settings → Media Management`.
- The OpenBao sync writes Readarr's API key to KV; pull it into Bazarr or Overseerr via Vault Secrets Operator.

## Upgrading

`appVersion` follows Readarr's development build numbers (no semver). To keep an existing config volume across reinstalls, set `persistence.volumeName` to the bound PV from a previous release.

## Support

- Upstream: <https://readarr.com/> · [GitHub](https://github.com/Readarr/Readarr)
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. Readarr is licensed under [GPL-3.0](https://github.com/Readarr/Readarr/blob/develop/LICENSE).

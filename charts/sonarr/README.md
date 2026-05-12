# Sonarr Helm Chart

![Version: 0.5.0](https://img.shields.io/badge/Version-0.5.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 4.0.16](https://img.shields.io/badge/AppVersion-4.0.16-informational?style=flat-square)

[Sonarr](https://sonarr.tv/) is a PVR for Usenet and BitTorrent users that watches for new episodes of your favorite TV shows, grabs them when they air, sorts them into a season-and-episode tree, and renames them to a consistent scheme. This chart runs Sonarr on Kubernetes using the [LinuxServer.io image](https://hub.docker.com/r/linuxserver/sonarr), with a `/ping` health probe wired to Sonarr's API, optional OpenBao API-key sync for downstream services, and three exposure modes (Ingress, Gateway API HTTPRoute, Cloudflare Tunnel).

Use Sonarr for TV shows. If you want movies, see the [radarr chart](../radarr); for subtitles, [bazarr](../bazarr); for indexer aggregation feeding both, [prowlarr](../prowlarr).

## Features

- `Deployment` with `Recreate` strategy by default — required for the `ReadWriteOnce` config volume backing Sonarr's SQLite store.
- Optional static-binding `PersistentVolumeClaim` for `/config` (50 GiB default). Pin a specific PV via `persistence.volumeName` to keep history across release reinstalls.
- Three north-south options on the `ClusterIP` service at port `8989`:
  - `networking.k8s.io/v1` Ingress.
  - Gateway API `HTTPRoute` (`gateway.networking.k8s.io/v1`) — controller-agnostic.
  - Cloudflare `TunnelBinding` (`networking.cfargotunnel.com/v1alpha1`).
- Optional init containers (`wait-for-config` + `api-key-sync`) that extract Sonarr's API key from `config.xml` and write it to OpenBao/Vault KV v2 via Kubernetes auth.
- Probes target `/ping` — Sonarr's built-in lightweight health endpoint, lighter than the HTML index.
- HPA scaffolding included; do not enable for production — Sonarr is single-writer.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- A `StorageClass` supporting `ReadWriteOnce` for `/config`.
- Shared media volumes (`/tv`, `/downloads`) provisioned out-of-band, preferably `ReadWriteMany`.
- Optional:
  - [Gateway API CRDs](https://gateway-api.sigs.k8s.io/) for `httpRoute`.
  - [cloudflare-operator](https://github.com/adyanth/cloudflare-operator) for `cfTunnel`.
  - OpenBao/Vault with Kubernetes auth for `openbao`.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install

```bash
helm install sonarr geekxflood/sonarr
helm install sonarr geekxflood/sonarr -f values.yaml
```

Sonarr ships with `enabled: false`. Set `enabled: true` (typically in your `values.yaml`) to render workloads.

## Configuration

### Global

| Parameter          | Description                          | Default    |
| ------------------ | ------------------------------------ | ---------- |
| `enabled`          | Master switch                        | `false`    |
| `replicaCount`     | Number of pods (keep `1`)            | `1`        |
| `nameOverride`     | Override the chart name in resources | `""`       |
| `fullnameOverride` | Override the fully qualified name    | `""`       |
| `strategy.type`    | Deployment strategy                  | `Recreate` |

### Image

| Parameter          | Description                                  | Default              |
| ------------------ | -------------------------------------------- | -------------------- |
| `image.repository` | Container image                              | `linuxserver/sonarr` |
| `image.tag`        | Image tag (falls back to `Chart.appVersion`) | `"latest"`           |
| `image.pullPolicy` | Image pull policy                            | `Always`             |
| `imagePullSecrets` | Pull secrets list                            | `[]`                 |

### Pod & Service Account

| Parameter                    | Description                        | Default |
| ---------------------------- | ---------------------------------- | ------- |
| `serviceAccount.create`      | Create a dedicated SA              | `true`  |
| `serviceAccount.automount`   | Auto-mount SA token                | `true`  |
| `serviceAccount.annotations` | SA annotations                     | `{}`    |
| `serviceAccount.name`        | Override SA name                   | `""`    |
| `podAnnotations`             | Annotations on pod template        | `{}`    |
| `podLabels`                  | Labels on pod template             | `{}`    |
| `podSecurityContext`         | Pod-level security context         | `{}`    |
| `securityContext`            | Container security context         | `{}`    |
| `env`                        | Container env (`PUID`/`PGID`/`TZ`) | `[]`    |

### Service

| Parameter      | Description              | Default     |
| -------------- | ------------------------ | ----------- |
| `service.type` | Kubernetes service type  | `ClusterIP` |
| `service.port` | Service & container port | `8989`      |

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

Omitting `backendRefs[*].name`/`port` defaults to this chart's service on `service.port`.

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
| `livenessProbe`  | Liveness probe (HTTP GET `/ping`:8989)  | `initialDelay 60s, period 60s` |
| `readinessProbe` | Readiness probe (HTTP GET `/ping`:8989) | `initialDelay 30s, period 30s` |

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

The init containers wait for Sonarr to create `/config/config.xml`, grep the `<ApiKey>` value, log into OpenBao via the pod's SA JWT, then write `api_key` and `url` into `openbao.kvPath`.

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
    value: "Europe/Paris"

persistence:
  enabled: true
  size: 20Gi
  storageClass: longhorn

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: sonarr-config-iscsi-pvc
  - name: tv
    persistentVolumeClaim:
      claimName: media-tv
  - name: downloads
    persistentVolumeClaim:
      claimName: media-downloads

volumeMounts:
  - name: config
    mountPath: /config
  - name: tv
    mountPath: /tv
  - name: downloads
    mountPath: /downloads

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: sonarr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - sonarr.example.com
      secretName: sonarr-tls
```

### HTTPRoute + OpenBao secret sync

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
    - sonarr.example.com
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
  kvPath: secret/data/media/sonarr
  serviceUrl: http://sonarr.media.svc.cluster.local:8989
```

CLI equivalent for a minimal Ingress install:

```bash
helm install sonarr geekxflood/sonarr \
  --set enabled=true \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set 'ingress.hosts[0].host=sonarr.example.com' \
  --set 'ingress.hosts[0].paths[0].path=/' \
  --set 'ingress.hosts[0].paths[0].pathType=Prefix'
```

## Persistence

| Mount        | Purpose                                               | Provided by chart?       |
| ------------ | ----------------------------------------------------- | ------------------------ |
| `/config`    | SQLite DB, release profiles, indexers, language profiles | Yes, via `persistence.*` |
| `/tv`        | TV library                                            | No, bring your own PVC   |
| `/downloads` | Download client output (shared with Radarr/SABnzbd)   | No, bring your own PVC   |

Prefer `ReadWriteMany` for `/tv` and `/downloads` so Sonarr, Radarr, Bazarr, and your download client can share them.

## Integration notes

- **Prowlarr → Sonarr**: Prowlarr pushes indexer definitions into Sonarr via Sonarr's REST API. In Prowlarr, add Sonarr as an application using `http://<sonarr-release>.<namespace>.svc:8989` and the API key from Sonarr's `Settings → General`.
- **Bazarr → Sonarr**: Bazarr's "Series" provider points at the same in-cluster service URL and reuses the API key.
- **Radarr & Sonarr coexistence**: keep them in the same namespace and share a download client so the `/downloads` PVC stays consistent.
- The OpenBao sync exposes Sonarr's API key under `openbao.kvPath` so Bazarr/Overseerr charts can mount it via Vault Secrets Operator instead of hard-coding values.

## Upgrading

`persistence.volumeName` enables static PV binding. If you previously had a PVC named `<release>-config-iscsi-pvc`, fetch its PV name and set `persistence.volumeName` to preserve Sonarr's database across reinstalls.

## Support

- Upstream: <https://sonarr.tv/> · [GitHub](https://github.com/Sonarr/Sonarr)
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. Sonarr is licensed under [GPL-3.0](https://github.com/Sonarr/Sonarr/blob/develop/LICENSE.md).

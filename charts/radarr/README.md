# Radarr Helm Chart

![Version: 0.5.0](https://img.shields.io/badge/Version-0.5.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 5.23.1](https://img.shields.io/badge/AppVersion-5.23.1-informational?style=flat-square)

[Radarr](https://radarr.video/) is a movie collection manager for Usenet and BitTorrent users. It monitors RSS feeds and indexers for new releases of movies you want, grabs them through your download client, and renames and organises the files into your library. This chart runs Radarr on Kubernetes using the [LinuxServer.io image](https://hub.docker.com/r/linuxserver/radarr) and ships with the wiring you need to expose the UI, persist `/config`, and sync the Radarr API key into [OpenBao](https://openbao.org/) / Vault so downstream services (Bazarr, Prowlarr, Overseerr) can authenticate against it.

## Features

- Single-replica `Deployment` with a `Recreate` strategy by default — safe for the `ReadWriteOnce` config volume Radarr uses for its SQLite database.
- Static-binding `PersistentVolumeClaim` for `/config` (50 GiB default). Pinning to a named PV via `persistence.volumeName` prevents the PVC from rebinding to a fresh empty volume after `helm uninstall`.
- Three north-south options, all backed by the same `ClusterIP` service on port `7878`:
  - Classic `networking.k8s.io/v1` Ingress.
  - Gateway API `HTTPRoute` (`gateway.networking.k8s.io/v1`) — controller-agnostic, works with Cilium Gateway, Istio, Envoy Gateway.
  - Cloudflare Tunnel `TunnelBinding` (`networking.cfargotunnel.com/v1alpha1`) for zero-trust exposure without a public LB.
- Optional init-container pipeline that waits for Radarr to generate `config.xml`, scrapes the API key, and writes it to an OpenBao KV v2 path via Kubernetes auth.
- HPA (`autoscaling/v2`) scaffolding is present, but note that Radarr is a stateful single-writer app — keep `replicaCount: 1` unless you understand the implications.
- HTTP `livenessProbe` and `readinessProbe` on `/` (port 7878), tunable from values.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- A `StorageClass` supporting `ReadWriteOnce` for the `/config` PVC.
- Movie/download volumes provisioned out-of-band (NFS, CephFS, iSCSI). The chart does not create media PVCs.
- Optional:
  - [Gateway API CRDs](https://gateway-api.sigs.k8s.io/) if using `httpRoute`.
  - [cloudflare-operator](https://github.com/adyanth/cloudflare-operator) if using `cfTunnel`.
  - An OpenBao or Vault cluster with the Kubernetes auth method configured if using `openbao`.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install

```bash
helm install radarr geekxflood/radarr
helm install radarr geekxflood/radarr -f values.yaml
```

Radarr ships with `enabled: false`. You must set `enabled: true` (or provide a `values.yaml` that does) for the chart to render any meaningful workloads.

## Configuration

### Global

| Parameter          | Description                            | Default    |
| ------------------ | -------------------------------------- | ---------- |
| `enabled`          | Master switch for the chart            | `false`    |
| `replicaCount`     | Number of pods (keep `1` for SQLite)   | `1`        |
| `nameOverride`     | Override the chart name in resources   | `""`       |
| `fullnameOverride` | Override the fully qualified name      | `""`       |
| `strategy.type`    | Deployment strategy (`Recreate` / RWO) | `Recreate` |

### Image

| Parameter          | Description                                  | Default              |
| ------------------ | -------------------------------------------- | -------------------- |
| `image.repository` | Container image                              | `linuxserver/radarr` |
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
| `service.port` | Service & container port | `7878`      |

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

When `backendRefs[*].name`/`port` is omitted, the template defaults to this chart's service on `service.port`.

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

| Parameter        | Description                         | Default                        |
| ---------------- | ----------------------------------- | ------------------------------ |
| `livenessProbe`  | Liveness probe (HTTP GET `/`:7878)  | `initialDelay 60s, period 60s` |
| `readinessProbe` | Readiness probe (HTTP GET `/`:7878) | `initialDelay 30s, period 30s` |

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

Radarr's SQLite database does not tolerate multiple writers. Treat the HPA as scaffolding only.

### OpenBao API-Key Sync

| Parameter                       | Description                                     | Default                               |
| ------------------------------- | ----------------------------------------------- | ------------------------------------- |
| `openbao.enabled`               | Run the wait + sync init containers             | `false`                               |
| `openbao.address`               | OpenBao/Vault HTTP address                      | `""`                                  |
| `openbao.authMount`             | Kubernetes auth mount path                      | `kubernetes`                          |
| `openbao.role`                  | OpenBao Kubernetes auth role                    | `""`                                  |
| `openbao.kvPath`                | KV v2 destination path (e.g. `secret/data/...`) | `""`                                  |
| `openbao.serviceUrl`            | Cluster URL stored alongside the API key        | `""`                                  |
| `openbao.initContainer.image`   | Image used to wait for `config.xml`             | `ghcr.io/apteno/alpine-jq:2024-03-14` |
| `openbao.vaultImage.repository` | Vault CLI image                                 | `hashicorp/vault`                     |
| `openbao.vaultImage.tag`        | Vault CLI tag                                   | `1.18`                                |

The sync runs on every pod start. It greps `<ApiKey>` from `/config/config.xml`, authenticates via the pod's service account JWT, and writes `api_key` and `url` keys into `openbao.kvPath`.

## Examples

### Basic install with Ingress and config PVC

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
      claimName: radarr-config-iscsi-pvc
  - name: movies
    persistentVolumeClaim:
      claimName: media-movies
  - name: downloads
    persistentVolumeClaim:
      claimName: media-downloads

volumeMounts:
  - name: config
    mountPath: /config
  - name: movies
    mountPath: /movies
  - name: downloads
    mountPath: /downloads

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: radarr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - radarr.example.com
      secretName: radarr-tls
```

When `persistence.enabled: true`, the PVC is created automatically — but you still need a `volumes[]` entry that references it (default name `<release>-config-iscsi-pvc`) and a matching `volumeMounts[]` entry on `/config`.

### Gateway API + Cloudflare Tunnel + OpenBao

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
    - radarr.internal.example.com
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

openbao:
  enabled: true
  address: https://openbao.openbao.svc.cluster.local:8200
  authMount: kubernetes
  role: media
  kvPath: secret/data/media/radarr
  serviceUrl: http://radarr.media.svc.cluster.local:7878
```

CLI equivalent for a minimal HTTPRoute install:

```bash
helm install radarr geekxflood/radarr \
  --set enabled=true \
  --set httpRoute.enabled=true \
  --set 'httpRoute.parentRefs[0].name=cilium-gateway' \
  --set 'httpRoute.parentRefs[0].namespace=gateway-system' \
  --set 'httpRoute.hostnames[0]=radarr.internal.example.com' \
  --set 'httpRoute.rules[0].matches[0].path.value=/' \
  --set 'httpRoute.rules[0].backendRefs[0].weight=1'
```

## Persistence

Radarr needs three classes of storage:

| Mount        | Purpose                                             | Provided by chart?        |
| ------------ | --------------------------------------------------- | ------------------------- |
| `/config`    | SQLite DB, settings, custom formats, indexers       | Yes, via `persistence.*`  |
| `/movies`    | Final movie library                                 | No, bring your own PVC    |
| `/downloads` | Download client output (shared with Sonarr/SABnzbd) | No, bring your own PVC    |

Use `ReadWriteMany` (NFS, CephFS) for `/movies` and `/downloads` if you intend to share them with Sonarr, Bazarr, or your download client. Use `ReadWriteOnce` for `/config`.

## Integration notes

- **Prowlarr → Radarr**: Prowlarr pushes indexer definitions into Radarr via Radarr's REST API. Configure the connection in Prowlarr using `http://<radarr-release>.<namespace>.svc:7878` and the API key from `Settings → General` (or pull it from OpenBao if you enabled the sync).
- **Bazarr → Radarr**: Bazarr reads Radarr's library and download history over the same API. Point Bazarr's "Movies" provider at the in-cluster service URL.
- **Overseerr / Jellyseerr → Radarr**: same pattern; both consume the Radarr API key.
- The OpenBao sync writes `api_key` and `url` to `openbao.kvPath`, so downstream charts using Vault Secrets Operator can pull the key without manual copy/paste.

## Upgrading

The persistence block uses static binding (`volumeName`). To migrate an existing volume across release names, record the current PV with `kubectl get pvc <name> -o jsonpath='{.spec.volumeName}'` and pass it as `persistence.volumeName` on the next install.

## Support

- Upstream: <https://radarr.video/> · [GitHub](https://github.com/Radarr/Radarr)
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. Radarr is licensed under [GPL-3.0](https://github.com/Radarr/Radarr/blob/develop/LICENSE).

# SABnzbd Helm Chart

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

A Helm chart for deploying [SABnzbd](https://sabnzbd.org/) on Kubernetes. SABnzbd is a multi-platform Usenet binary downloader written in Python that automates the process of downloading, repairing (PAR2), unpacking, and post-processing NZB content. It is the canonical Usenet download client used alongside the *arr suite (Sonarr, Radarr, Lidarr, Readarr) in self-hosted media stacks.

This chart deploys the [LinuxServer.io SABnzbd image](https://hub.docker.com/r/linuxserver/sabnzbd), which provides PUID/PGID-based file ownership management and a hardened runtime.

## Features

- Configurable image, replicas, resources, probes, and pod metadata.
- Two-volume persistence model (`config`, `downloads`) with dynamic or static PVC binding via `volumeName`, or external claims via `existingClaim`.
- HTTP service on port 8080 with optional `Ingress` (standard `networking.k8s.io/v1`).
- Optional Gateway API `HTTPRoute` for vanilla Kubernetes Gateway implementations (Cilium Gateway API, Istio, Envoy Gateway).
- Optional Cloudflare Tunnel `TunnelBinding` (cloudflare-operator CRD) for zero-trust public exposure without an Ingress.
- Liveness and readiness probes pre-wired against the SABnzbd web UI.
- Recreate strategy by default to keep `ReadWriteOnce` volumes safe across rollouts.
- Custom `volumes` / `volumeMounts` for additional mounts (e.g., shared media library, NFS, incomplete-downloads).
- Init containers can be injected through `initContainers` (declared in the deployment template).

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- A `StorageClass` capable of provisioning `ReadWriteOnce` (or shared `ReadWriteMany`) volumes for `/config` and `/downloads`.
- If `httpRoute.enabled`, a Gateway API controller (Cilium, Istio, Envoy Gateway, etc.) and an existing `Gateway` resource.
- If `cfTunnel.enabled`, the [cloudflare-operator](https://github.com/STRRL/cloudflare-tunnel-ingress-controller) (or compatible) installed and a `Tunnel` already provisioned.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install sabnzbd geekxflood/sabnzbd
```

### Install with custom values

```bash
helm install sabnzbd geekxflood/sabnzbd -f values.yaml
```

## Configuration

### Global Parameters

| Parameter      | Description                         | Default |
| -------------- | ----------------------------------- | ------- |
| `enabled`      | Enable/disable the chart deployment | `true`  |
| `replicaCount` | Number of SABnzbd replicas          | `1`     |

### Image Parameters

| Parameter          | Description              | Default               |
| ------------------ | ------------------------ | --------------------- |
| `image.repository` | SABnzbd image repository | `linuxserver/sabnzbd` |
| `image.pullPolicy` | Image pull policy        | `Always`              |
| `image.tag`        | Image tag                | `"latest"`            |
| `imagePullSecrets` | Image pull secrets       | `[]`                  |

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

| Parameter | Description                                   | Default                                                       |
| --------- | --------------------------------------------- | ------------------------------------------------------------- |
| `env`     | Environment variables passed to the container | `PUID=1000`, `PGID=100`, `TZ=UTC` (LinuxServer.io convention) |

### Service Parameters

| Parameter      | Description                       | Default     |
| -------------- | --------------------------------- | ----------- |
| `service.type` | Service type                      | `ClusterIP` |
| `service.port` | Service port (SABnzbd web UI/API) | `8080`      |

### Ingress Parameters

| Parameter             | Description                 | Default |
| --------------------- | --------------------------- | ------- |
| `ingress.enabled`     | Enable Ingress              | `false` |
| `ingress.className`   | Ingress class name          | `""`    |
| `ingress.annotations` | Ingress annotations         | `{}`    |
| `ingress.hosts`       | Ingress hosts configuration | `[]`    |
| `ingress.tls`         | Ingress TLS configuration   | `[]`    |

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

| Parameter          | Description                      | Default |
| ------------------ | -------------------------------- | ------- |
| `cfTunnel.enabled` | Enable Cloudflare Tunnel binding | `false` |

### Probes

| Parameter        | Description     | Default                                          |
| ---------------- | --------------- | ------------------------------------------------ |
| `livenessProbe`  | Liveness probe  | HTTP `GET /` on port 8080, delay 60s, period 60s |
| `readinessProbe` | Readiness probe | HTTP `GET /` on port 8080, delay 30s, period 30s |

### Persistence Parameters

| Parameter                             | Description                            | Default         |
| ------------------------------------- | -------------------------------------- | --------------- |
| `persistence.config.enabled`          | Provision/mount `/config` PVC          | `false`         |
| `persistence.config.existingClaim`    | Use an existing PVC for config         | `""`            |
| `persistence.config.name`             | PVC name override                      | `""`            |
| `persistence.config.storageClass`     | Storage class for config PVC           | `""`            |
| `persistence.config.accessMode`       | Access mode                            | `ReadWriteOnce` |
| `persistence.config.size`             | Storage request                        | `10Gi`          |
| `persistence.config.volumeName`       | Bind to a specific PV (static binding) | `""`            |
| `persistence.downloads.enabled`       | Provision/mount `/downloads` PVC       | `false`         |
| `persistence.downloads.existingClaim` | Use an existing PVC for downloads      | `""`            |
| `persistence.downloads.name`          | PVC name override                      | `""`            |
| `persistence.downloads.storageClass`  | Storage class for downloads PVC        | `""`            |
| `persistence.downloads.accessMode`    | Access mode                            | `ReadWriteOnce` |
| `persistence.downloads.size`          | Storage request                        | `100Gi`         |
| `persistence.downloads.volumeName`    | Bind to a specific PV (static binding) | `""`            |

### Storage Parameters

| Parameter      | Description              | Default |
| -------------- | ------------------------ | ------- |
| `volumes`      | Additional volumes       | `[]`    |
| `volumeMounts` | Additional volume mounts | `[]`    |

### Autoscaling Parameters

| Parameter             | Description                 | Default |
| --------------------- | --------------------------- | ------- |
| `autoscaling.enabled` | Enable HPA (template-aware) | `false` |

### Resource Management & Scheduling

| Parameter      | Description                  | Default |
| -------------- | ---------------------------- | ------- |
| `resources`    | Resource requests and limits | `{}`    |
| `nodeSelector` | Node selector                | `{}`    |
| `tolerations`  | Tolerations                  | `[]`    |
| `affinity`     | Affinity rules               | `{}`    |

## Examples

### Basic install with persistence and Ingress

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "100"
  - name: TZ
    value: "Europe/Paris"

persistence:
  config:
    enabled: true
    size: 5Gi
    storageClass: standard
  downloads:
    enabled: true
    size: 500Gi
    storageClass: standard

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: sabnzbd.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: sabnzbd-tls
      hosts:
        - sabnzbd.example.com
```

### Shared media library plus separate incomplete-downloads volume

SABnzbd benefits from keeping the incomplete-downloads directory on local/fast storage and the completed-downloads directory on a shared NFS volume that the *arr apps and the media server can read.

```yaml
enabled: true

persistence:
  config:
    enabled: true
    size: 5Gi
  downloads:
    enabled: true
    existingClaim: media-downloads-nfs

volumes:
  - name: incomplete
    emptyDir:
      sizeLimit: 50Gi

volumeMounts:
  - name: incomplete
    mountPath: /incomplete-downloads

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: sabnzbd.example.com
      paths:
        - path: /
          pathType: Prefix
```

In the SABnzbd UI, set **Folders -> Temporary Download Folder** to `/incomplete-downloads` and **Completed Download Folder** to `/downloads`.

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
    - sabnzbd.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1

persistence:
  config:
    enabled: true
  downloads:
    enabled: true
```

## Persistence

SABnzbd uses two mount points wired directly into the deployment template:

- `/config` — server configuration (`sabnzbd.ini`), categories, history database, scripts, and the API key. Mounted from `persistence.config` when enabled.
- `/downloads` — completed downloads (default category target). Mounted from `persistence.downloads` when enabled.

The chart does **not** mount `/incomplete-downloads` by default. If you want SABnzbd's temporary directory on a different volume (recommended for fast SSD scratch space), add an entry to `volumes`/`volumeMounts` as shown above and configure the path in the SABnzbd UI.

The default `strategy.type: Recreate` ensures the old pod releases the RWO claim before the new one starts.

## Integration notes

### As a download client in Sonarr / Radarr / Lidarr / Readarr

1. In SABnzbd, generate an API key (Config -> General). It is stored in `/config/sabnzbd.ini` — keep the config PVC private.
2. In each *arr application, add SABnzbd under **Settings -> Download Clients**:
   - Host: in-cluster service name, e.g. `sabnzbd.<namespace>.svc.cluster.local`
   - Port: `8080`
   - URL Base: leave empty unless you exposed it under a subpath
   - API Key: the key from step 1
   - Category: configure a SABnzbd category that maps to the *arr app (e.g., `tv-sonarr`, `movies-radarr`)
3. Map SABnzbd's `/downloads` to the same physical path the *arr apps see for completed downloads (use the same `existingClaim` or `volumeName` on both deployments).

### Remote access from arr stacks

Because the service is `ClusterIP` by default, *arr applications running in the same cluster reach SABnzbd over its service DNS. There is no need to expose SABnzbd publicly unless you want browser access to the web UI.

## Upgrading

### To 0.2.0

- Added Gateway API `HTTPRoute` template.
- Added Cloudflare Tunnel `TunnelBinding` template.

## Uninstallation

```bash
helm uninstall sabnzbd
```

PVCs created by the chart are not deleted automatically. Remove them manually if desired:

```bash
kubectl delete pvc -l app.kubernetes.io/name=sabnzbd
```

## Support

- Upstream SABnzbd: <https://sabnzbd.org/>
- LinuxServer.io image: <https://hub.docker.com/r/linuxserver/sabnzbd>
- Chart Repository Issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. SABnzbd is licensed under the GNU GPL v2. See the [SABnzbd license](https://github.com/sabnzbd/sabnzbd/blob/develop/licenses/Licenses.txt).

# LazyLibrarian Helm Chart

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

[LazyLibrarian](https://gitlab.com/LazyLibrarian/LazyLibrarian) is an alternative ebook and audiobook manager. Where Readarr is *arr-stack-native and Usenet/torrent-focused, LazyLibrarian also pulls from direct-download sites (LibGen, ebook torrent indexers) and Goodreads/OpenLibrary, optionally driving a Calibre library through bundled mods. This chart runs LazyLibrarian on Kubernetes using the [LinuxServer.io image](https://hub.docker.com/r/linuxserver/lazylibrarian) and exposes it via Ingress, Gateway API HTTPRoute, or Cloudflare Tunnel.

Pick LazyLibrarian if you want broader sourcing (including web-scraping) and a simpler single-app workflow. Pick the [readarr chart](../readarr) if you want tight Prowlarr/Sonarr/Radarr integration.

## Features

- `Deployment` with `Recreate` strategy — `ReadWriteOnce` config volume.
- Optional static-binding `PersistentVolumeClaim` for `/config` (10 GiB default — LazyLibrarian's metadata cache is small).
- `ClusterIP` service on port `5299`.
- Three exposure modes: `Ingress`, Gateway API `HTTPRoute`, Cloudflare `TunnelBinding`.
- Pre-populated `env` with `PUID=1000`, `PGID=1000`, `TZ=UTC`. Commented-out `DOCKER_MODS` example shows how to add Calibre and FFmpeg to the image.
- Probes hit `/` on port 5299.
- OpenBao integration scaffolding is included but LazyLibrarian doesn't expose an API key from `config.xml` the same way the *arr apps do — see the OpenBao section below for caveats.
- HPA scaffolding included; keep `replicaCount: 1`.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- A `StorageClass` supporting `ReadWriteOnce` for `/config`.
- Out-of-band volumes for `/books`, `/audiobooks`, `/downloads`.
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
helm install lazylibrarian geekxflood/lazylibrarian
helm install lazylibrarian geekxflood/lazylibrarian -f values.yaml
```

LazyLibrarian ships with `enabled: false`. Set `enabled: true` to render workloads.

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

| Parameter          | Description                                  | Default                             |
| ------------------ | -------------------------------------------- | ----------------------------------- |
| `image.repository` | Container image                              | `lscr.io/linuxserver/lazylibrarian` |
| `image.tag`        | Image tag (falls back to `Chart.appVersion`) | `"latest"`                          |
| `image.pullPolicy` | Image pull policy                            | `Always`                            |
| `imagePullSecrets` | Pull secrets list                            | `[]`                                |

### Pod & Service Account

| Parameter                    | Description                         | Default                              |
| ---------------------------- | ----------------------------------- | ------------------------------------ |
| `serviceAccount.create`      | Create a dedicated SA               | `true`                               |
| `serviceAccount.automount`   | Auto-mount SA token                 | `true`                               |
| `serviceAccount.annotations` | SA annotations                      | `{}`                                 |
| `serviceAccount.name`        | Override SA name                    | `""`                                 |
| `podAnnotations`             | Pod annotations                     | `{}`                                 |
| `podLabels`                  | Pod labels                          | `{}`                                 |
| `podSecurityContext`         | Pod-level security context          | `{}`                                 |
| `securityContext`            | Container security context          | `{}`                                 |
| `env`                        | Container env (preset PUID/PGID/TZ) | `[{PUID:1000},{PGID:1000},{TZ:UTC}]` |

### Service

| Parameter      | Description              | Default     |
| -------------- | ------------------------ | ----------- |
| `service.type` | Kubernetes service type  | `ClusterIP` |
| `service.port` | Service & container port | `5299`      |

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

| Parameter            | Description                               | Default |
| -------------------- | ----------------------------------------- | ------- |
| `cfTunnel.enabled`   | Render a `TunnelBinding`                  | `false` |
| `cfTunnel.tunnelRef` | Reference to a `ClusterTunnel`/`Tunnel`   | `{}`    |
| `cfTunnel.subjects`  | Tunnel subjects (defaults to the service) | `[]`    |

### Persistence (`/config`)

| Parameter                  | Description                                        | Default                |
| -------------------------- | -------------------------------------------------- | ---------------------- |
| `persistence.enabled`      | Render the config PVC                              | `false`                |
| `persistence.name`         | PVC name override (default `<release>-config-pvc`) | `""`                   |
| `persistence.storageClass` | Storage class                                      | `""` (cluster default) |
| `persistence.accessMode`   | PVC access mode                                    | `ReadWriteOnce`        |
| `persistence.size`         | Requested storage                                  | `10Gi`                 |
| `persistence.volumeName`   | Bind to a specific `PersistentVolume`              | `""`                   |

### Volumes / Volume Mounts

| Parameter      | Description                         | Default |
| -------------- | ----------------------------------- | ------- |
| `volumes`      | Additional `pod.spec.volumes`       | `[]`    |
| `volumeMounts` | Additional `container.volumeMounts` | `[]`    |

### Probes

| Parameter        | Description                         | Default                        |
| ---------------- | ----------------------------------- | ------------------------------ |
| `livenessProbe`  | Liveness probe (HTTP GET `/`:5299)  | `initialDelay 60s, period 60s` |
| `readinessProbe` | Readiness probe (HTTP GET `/`:5299) | `initialDelay 30s, period 30s` |

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

### OpenBao Block

| Parameter                       | Description                  | Default                               |
| ------------------------------- | ---------------------------- | ------------------------------------- |
| `openbao.enabled`               | Reserved                     | `false`                               |
| `openbao.address`               | OpenBao/Vault HTTP address   | `""`                                  |
| `openbao.authMount`             | Kubernetes auth mount        | `kubernetes`                          |
| `openbao.role`                  | OpenBao Kubernetes auth role | `""`                                  |
| `openbao.kvPath`                | KV v2 destination path       | `""`                                  |
| `openbao.serviceUrl`            | Cluster URL                  | `""`                                  |
| `openbao.initContainer.image`   | Init container image         | `ghcr.io/apteno/alpine-jq:2024-03-14` |
| `openbao.vaultImage.repository` | Vault CLI image              | `hashicorp/vault`                     |
| `openbao.vaultImage.tag`        | Vault CLI tag                | `1.18`                                |

LazyLibrarian's config schema differs from the *arr apps (no top-level `<ApiKey>` element in `config.xml`), so this block is plumbed in values but not consumed by an init container in the current templates. Use Vault Secrets Operator + a hand-managed KV entry if you need LazyLibrarian credentials in OpenBao.

## Examples

### Basic install with Ingress

```yaml
enabled: true

# env is preset with PUID/PGID/TZ; override here only if you need different values
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
      claimName: lazylibrarian-config-pvc
  - name: books
    persistentVolumeClaim:
      claimName: media-books
  - name: downloads
    persistentVolumeClaim:
      claimName: media-downloads

volumeMounts:
  - name: config
    mountPath: /config
  - name: books
    mountPath: /books
  - name: downloads
    mountPath: /downloads

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: lazylibrarian.example.com
      paths:
        - path: /
          pathType: Prefix
```

### Calibre + FFmpeg mods + HTTPRoute

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: TZ
    value: "Europe/Paris"
  - name: DOCKER_MODS
    value: "linuxserver/mods:universal-calibre|linuxserver/mods:lazylibrarian-ffmpeg"

persistence:
  enabled: true
  size: 5Gi

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: lazylibrarian-config-pvc
  - name: books
    persistentVolumeClaim:
      claimName: media-books

volumeMounts:
  - name: config
    mountPath: /config
  - name: books
    mountPath: /books

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - lazylibrarian.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1
```

`DOCKER_MODS` is a [LinuxServer.io feature](https://docs.linuxserver.io/general/container-customization/) that side-loads extra tools at container start. The Calibre mod enables format conversion; the FFmpeg mod enables audiobook re-encoding.

## Persistence

| Mount         | Purpose                                               | Provided by chart?       |
| ------------- | ----------------------------------------------------- | ------------------------ |
| `/config`     | SQLite DB, OPDS cache, Goodreads/OpenLibrary metadata | Yes, via `persistence.*` |
| `/books`      | Ebook library (and optionally a Calibre library tree) | No, bring your own PVC   |
| `/audiobooks` | Audiobook library                                     | No, bring your own PVC   |
| `/downloads`  | Download client output                                | No, bring your own PVC   |

## Integration notes

- **Calibre**: enable the `linuxserver/mods:universal-calibre` Docker mod via `DOCKER_MODS` and point LazyLibrarian's library at a Calibre library directory (`metadata.db` + author folders) to read/write through Calibre's format conversion.
- **Download clients**: LazyLibrarian talks to SABnzbd, NZBGet, Transmission, qBittorrent, Deluge, and rTorrent over HTTP — configure them at `Settings → Downloaders` using their in-cluster service URLs.
- **Prowlarr**: Prowlarr does **not** ship app-sync for LazyLibrarian. You must configure each indexer manually in `Settings → Providers`. If you want Prowlarr-managed indexers, use Readarr instead.

## Upgrading

`appVersion` is pinned to `latest` upstream — LazyLibrarian doesn't publish discrete release tags through the LSIO image. Use `image.tag` to pin to a Docker Hub digest if you need reproducibility.

## Support

- Upstream: <https://lazylibrarian.gitlab.io/> · [GitLab repo](https://gitlab.com/LazyLibrarian/LazyLibrarian)
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. LazyLibrarian is licensed under the [GPL-3.0](https://gitlab.com/LazyLibrarian/LazyLibrarian/-/blob/master/LICENSE.txt).

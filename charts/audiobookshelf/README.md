# Audiobookshelf Helm Chart

![Version: 0.6.0](https://img.shields.io/badge/Version-0.6.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

[Audiobookshelf](https://www.audiobookshelf.org/) is a self-hosted audiobook and podcast server. It scans on-disk libraries, normalizes metadata, tracks listening progress per user, and streams to iOS and Android apps with offline sync. Deploy this chart when you want to keep your audiobook collection on your own storage instead of relying on Audible — multi-user progress sync, OPDS, and ebook reader support all come along.

## Features

- HTTP `Ingress` and Gateway API `HTTPRoute` exposure (use either, or both)
- Cloudflare Tunnel integration via `TunnelBinding` for zero-trust external access
- Two managed PVCs: one for the config database and one for cached metadata/covers
- Long-running stream-friendly liveness/readiness probes on `/healthcheck`
- HPA hook (chart wiring present; enable via `autoscaling.enabled`)
- OpenBao / Vault Secrets Operator integration for injecting credentials without committing them to values
- Pluggable extra `volumes` / `volumeMounts` for mounting media libraries from existing PVCs

## Prerequisites

- Kubernetes 1.19+ (HTTPRoute requires Gateway API CRDs `gateway.networking.k8s.io/v1`)
- Helm 3.0+
- A PV provisioner if `persistence.config.enabled` or `persistence.metadata.enabled` is `true`
- Optional: cloudflare-operator (`networking.cfargotunnel.com/v1alpha1`) for Cloudflare Tunnel
- Optional: Vault Secrets Operator if `openbao.enabled=true`
- Optional: an existing PVC for your audiobook media library — the chart does not provision media storage

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install with default values

```bash
helm install audiobookshelf geekxflood/audiobookshelf
```

### Install with custom values

```bash
helm install audiobookshelf geekxflood/audiobookshelf -f values.yaml
```

## Configuration

### Image

| Parameter          | Description       | Default                          |
| ------------------ | ----------------- | -------------------------------- |
| `image.repository` | Image repository  | `ghcr.io/advplyr/audiobookshelf` |
| `image.tag`        | Image tag         | `latest`                         |
| `image.pullPolicy` | Image pull policy | `Always`                         |
| `replicaCount`     | Replica count     | `1`                              |

### Service

| Parameter      | Description  | Default     |
| -------------- | ------------ | ----------- |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80`        |

### Ingress

| Parameter             | Description         | Default |
| --------------------- | ------------------- | ------- |
| `ingress.enabled`     | Enable Ingress      | `false` |
| `ingress.className`   | IngressClass name   | `""`    |
| `ingress.annotations` | Ingress annotations | `{}`    |
| `ingress.hosts`       | Host rules          | `[]`    |
| `ingress.tls`         | TLS configuration   | `[]`    |

### HTTPRoute (Gateway API)

| Parameter               | Description                                            | Default |
| ----------------------- | ------------------------------------------------------ | ------- |
| `httpRoute.enabled`     | Enable Gateway API HTTPRoute                           | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                                  | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                                       | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments (required when enabled) | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                            | `[]`    |
| `httpRoute.rules`       | Route rules (matches + backendRefs)                    | `[]`    |

When `backendRefs[*].name` and `port` are omitted, the route targets this chart's own service on `service.port`.

### Cloudflare Tunnel

| Parameter              | Description                                  | Default          |
| ---------------------- | -------------------------------------------- | ---------------- |
| `cfTunnel.enabled`     | Create a `TunnelBinding`                     | `false`          |
| `cfTunnel.tunnelRef.name` | Name of the (Cluster)Tunnel to bind to    | `""`             |
| `cfTunnel.tunnelRef.kind` | `ClusterTunnel` or `Tunnel`               | `ClusterTunnel`  |
| `cfTunnel.subjects`    | List of service subjects (name + fqdn + protocol) | `[]`     |

### Persistence

| Parameter                           | Description                          | Default         |
| ----------------------------------- | ------------------------------------ | --------------- |
| `persistence.config.enabled`        | Create config PVC                    | `true`          |
| `persistence.config.size`           | Config PVC size                      | `5Gi`           |
| `persistence.config.storageClass`   | Config PVC storage class             | `""`            |
| `persistence.config.accessMode`     | Config PVC access mode               | `ReadWriteOnce` |
| `persistence.metadata.enabled`      | Create metadata PVC                  | `true`          |
| `persistence.metadata.size`         | Metadata PVC size                    | `10Gi`          |
| `persistence.metadata.storageClass` | Metadata PVC storage class           | `""`            |
| `persistence.metadata.accessMode`   | Metadata PVC access mode             | `ReadWriteOnce` |
| `volumes`                           | Additional volumes (e.g. media PVCs) | `[]`            |
| `volumeMounts`                      | Additional volume mounts             | `[]`            |

The chart only creates and mounts the `config` and `metadata` PVCs as resources. To actually mount them into the container you must also add them to `volumes`/`volumeMounts` (see Examples).

### Resources & Probes

| Parameter                        | Description                  | Default      |
| -------------------------------- | ---------------------------- | ------------ |
| `resources.requests.memory`      | Memory request               | `256Mi`      |
| `resources.requests.cpu`         | CPU request                  | `250m`       |
| `resources.limits.memory`        | Memory limit                 | `1Gi`        |
| `resources.limits.cpu`           | CPU limit                    | `2000m`      |
| `livenessProbe.httpGet.path`     | Liveness probe path          | `/healthcheck` |
| `readinessProbe.httpGet.path`    | Readiness probe path         | `/healthcheck` |

### OpenBao (Vault Secrets Operator)

| Parameter                            | Description                          | Default        |
| ------------------------------------ | ------------------------------------ | -------------- |
| `openbao.enabled`                    | Enable VSO integration               | `false`        |
| `openbao.vaultConnectionRef`         | VaultConnection reference            | `""`           |
| `openbao.vaultAuth.create`           | Create VaultAuth resource            | `false`        |
| `openbao.vaultAuth.role`             | Kubernetes auth role                 | `""`           |
| `openbao.staticSecret.enabled`       | Sync a static secret from KV v2      | `false`        |
| `openbao.staticSecret.path`          | KV path                              | `""`           |
| `openbao.staticSecret.refreshAfter`  | Refresh interval                     | `1h`           |

## Examples

### Ingress with a config, metadata, and media library

This is the typical home-server shape: the chart manages the two small PVCs for config/metadata, and you mount an existing PVC (or NFS, etc.) for the actual audiobook files.

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  hosts:
    - host: audiobookshelf.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: audiobookshelf-tls
      hosts:
        - audiobookshelf.example.com

env:
  - name: TZ
    value: "America/New_York"

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: audiobookshelf-config-pvc
  - name: metadata
    persistentVolumeClaim:
      claimName: audiobookshelf-metadata-pvc
  - name: audiobooks
    persistentVolumeClaim:
      claimName: audiobooks
  - name: podcasts
    persistentVolumeClaim:
      claimName: podcasts

volumeMounts:
  - name: config
    mountPath: /config
  - name: metadata
    mountPath: /metadata
  - name: audiobooks
    mountPath: /audiobooks
  - name: podcasts
    mountPath: /podcasts
```

The long proxy timeouts matter — chapter scrubbing on a multi-hour audiobook will otherwise hit nginx's default 60-second read timeout mid-stream.

### Gateway API with Cloudflare Tunnel

Skip Ingress entirely, terminate TLS at a Cilium Gateway listener, and additionally expose the service through a Cloudflare Tunnel for friends-and-family access.

```yaml
ingress:
  enabled: false

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - audiobookshelf.example.com
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
    name: home-cluster
    kind: ClusterTunnel
  subjects:
    - name: audiobookshelf
      spec:
        fqdn: audiobookshelf.tunnel.example.com
        protocol: http
```

Cilium operators: `parentRefs[*].port` is ignored — target a listener with `sectionName`. Cross-namespace `backendRefs` require a `ReferenceGrant`.

## Persistence

Audiobookshelf needs three kinds of storage. The chart manages the first two; you bring the third.

| Volume     | Mount path    | Provided by                      | Purpose                                  |
| ---------- | ------------- | -------------------------------- | ---------------------------------------- |
| config     | `/config`     | Chart-managed PVC (`persistence.config`)   | Server database, sessions, user data |
| metadata   | `/metadata`   | Chart-managed PVC (`persistence.metadata`) | Cover art and cached metadata        |
| media      | your choice   | You — via `volumes` / `volumeMounts`       | The actual `.m4b` / `.mp3` files     |

Back up `/config` regularly — it contains the entire user/progress database.

## Upgrading

`helm upgrade audiobookshelf geekxflood/audiobookshelf` is safe between minor versions. PVCs are not touched by upgrades; if you delete the release, the PVCs remain by default.

## Support

- Upstream project: [audiobookshelf.org](https://www.audiobookshelf.org/) — source at [advplyr/audiobookshelf](https://github.com/advplyr/audiobookshelf)
- Mobile apps: [iOS](https://apps.apple.com/us/app/audiobookshelf/id1614635225) / [Android](https://play.google.com/store/apps/details?id=com.audiobookshelf.app)
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. Audiobookshelf is licensed under [GPL-3.0](https://github.com/advplyr/audiobookshelf/blob/master/LICENSE).

# Tdarr Server Helm Chart

![Version: 0.5.2](https://img.shields.io/badge/Version-0.5.2-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 2.73.01](https://img.shields.io/badge/AppVersion-2.73.01-informational?style=flat-square)

A Helm chart for deploying the [Tdarr](https://home.tdarr.io/) server (orchestrator) standalone. The server hosts the web UI, holds the library database, and coordinates work across external `tdarr-node` workers.

Pair this chart with one or more [`tdarr-node`](https://github.com/geekxflood/helm-charts/tree/main/charts/tdarr_node) releases for distributed transcoding. If you only want a single co-located server-plus-node pod, use the umbrella [`tdarr`](https://github.com/geekxflood/helm-charts/tree/main/charts/tdarr) chart instead.

## Features

- Standalone Tdarr server / orchestrator with web UI
- Exposes both UI (`8265`) and node-registration (`8266`) ports on a single Service
- Ingress and Gateway API `HTTPRoute` for the web UI
- PVC for server data with optional NFS-backed transcode cache
- HPA toggle and configurable probes
- Default `internalNode=false` so this pod is dedicated to orchestration

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- PersistentVolume provisioner (PVC for server data is enabled by default)
- Optional: NFS server if you want to share a transcode cache with `tdarr-node` workers
- For Gateway API: an installed Gateway controller (Cilium, Istio, Envoy Gateway) and `HTTPRoute` CRDs

This chart does not configure GPU - GPU work belongs on `tdarr-node`.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install tdarr-server geekxflood/tdarr-server
```

### Install with custom values

```bash
helm install tdarr-server geekxflood/tdarr-server -f values.yaml
```

## Configuration

### Core Parameters

| Parameter          | Description                      | Default |
| ------------------ | -------------------------------- | ------- |
| `replicaCount`     | Number of replicas (keep at `1`) | `1`     |
| `nameOverride`     | Override chart name              | `""`    |
| `fullnameOverride` | Override full resource name      | `""`    |

### Image

| Parameter          | Description                                         | Default                     |
| ------------------ | --------------------------------------------------- | --------------------------- |
| `image.repository` | Tdarr image repository                              | `ghcr.io/haveagitgat/tdarr` |
| `image.pullPolicy` | Image pull policy                                   | `IfNotPresent`              |
| `image.tag`        | Image tag (defaults to chart `appVersion` if empty) | `""`                        |
| `imagePullSecrets` | Image pull secrets                                  | `[]`                        |

### Service Account

| Parameter                    | Description             | Default |
| ---------------------------- | ----------------------- | ------- |
| `serviceAccount.create`      | Create a ServiceAccount | `true`  |
| `serviceAccount.automount`   | Automount the SA token  | `true`  |
| `serviceAccount.annotations` | Annotations             | `{}`    |
| `serviceAccount.name`        | Override SA name        | `""`    |

### Pod & Environment

| Parameter            | Description                   | Default                                                                                                |
| -------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------ |
| `podAnnotations`     | Pod annotations               | `{}`                                                                                                   |
| `podLabels`          | Pod labels                    | `{}`                                                                                                   |
| `podSecurityContext` | Pod security context          | `{}`                                                                                                   |
| `securityContext`    | Container security context    | `{}`                                                                                                   |
| `env`                | Environment variables         | `PUID=1000`, `PGID=100`, `TZ=Etc/UTC`, `serverPort=8266`, `webUIPort=8265`, `internalNode=false`       |
| `envFrom`            | Env from `secret`/`configmap` | `[]`                                                                                                   |
| `runtime.enabled`    | Set `runtimeClassName`        | `false`                                                                                                |
| `runtime.name`       | `runtimeClassName` value      | `""`                                                                                                   |

### Service

| Parameter            | Description            | Default     |
| -------------------- | ---------------------- | ----------- |
| `service.type`       | Service type           | `ClusterIP` |
| `service.webUIPort`  | Web UI port            | `8265`      |
| `service.serverPort` | Node registration port | `8266`      |

### Ingress

| Parameter             | Description         | Default |
| --------------------- | ------------------- | ------- |
| `ingress.enabled`     | Enable Ingress      | `false` |
| `ingress.className`   | Ingress class       | `""`    |
| `ingress.annotations` | Ingress annotations | `{}`    |
| `ingress.hosts`       | Ingress hosts       | `[]`    |
| `ingress.tls`         | Ingress TLS         | `[]`    |

### HTTPRoute (Gateway API)

| Parameter               | Description                                        | Default |
| ----------------------- | -------------------------------------------------- | ------- |
| `httpRoute.enabled`     | Create a Gateway API `HTTPRoute`                   | `false` |
| `httpRoute.annotations` | Route annotations                                  | `{}`    |
| `httpRoute.labels`      | Route labels                                       | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener references                      | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                        | `[]`    |
| `httpRoute.rules`       | Route rules; defaults to this Service when omitted | `[]`    |

### Persistence & Cache

| Parameter                  | Description                                                               | Default         |
| -------------------------- | ------------------------------------------------------------------------- | --------------- |
| `persistence.enabled`      | Create a PVC and mount at `/app/server` (with `/app/configs` via subPath) | `true`          |
| `persistence.size`         | PVC size                                                                  | `10Gi`          |
| `persistence.storageClass` | StorageClass                                                              | `""`            |
| `persistence.accessMode`   | Access mode                                                               | `ReadWriteOnce` |
| `nfsCache.enabled`         | Mount a shared NFS export at `/transcode_cache` (with optional `subPath`) | `false`         |
| `nfsCache.server`          | NFS server address                                                        | `""`            |
| `nfsCache.path`            | NFS export path                                                           | `""`            |
| `nfsCache.subPath`         | Per-instance subPath (use `server` to isolate from nodes)                 | `""`            |
| `volumes`                  | Additional volumes (e.g. media library PVC)                               | `[]`            |
| `volumeMounts`             | Additional volume mounts                                                  | `[]`            |

### Probes, Resources, Autoscaling

| Parameter                                       | Description                | Default                                   |
| ----------------------------------------------- | -------------------------- | ----------------------------------------- |
| `livenessProbe`                                 | Liveness probe             | HTTP GET `/` on `8265`, 90s initial delay |
| `readinessProbe`                                | Readiness probe            | HTTP GET `/` on `8265`, 60s initial delay |
| `resources`                                     | Resource requests / limits | `{}`                                      |
| `autoscaling.enabled`                           | Enable HPA                 | `false`                                   |
| `autoscaling.minReplicas`                       | Minimum replicas           | `1`                                       |
| `autoscaling.maxReplicas`                       | Maximum replicas           | `100`                                     |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU %               | `80`                                      |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory %            | `80`                                      |

### Scheduling

| Parameter      | Description     | Default |
| -------------- | --------------- | ------- |
| `nodeSelector` | Node selector   | `{}`    |
| `tolerations`  | Pod tolerations | `[]`    |
| `affinity`     | Affinity rules  | `{}`    |

## Examples

### Minimal server install with Ingress and shared NFS cache

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: tdarr.example.com
      paths:
        - path: /
          pathType: Prefix

persistence:
  enabled: true
  size: 20Gi
  storageClass: longhorn

nfsCache:
  enabled: true
  server: 192.0.2.10
  path: /exports/transcode
  subPath: server

volumes:
  - name: media
    persistentVolumeClaim:
      claimName: media-library

volumeMounts:
  - name: media
    mountPath: /media
```

### Gateway API HTTPRoute

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
    - tdarr.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1
```

### Server-plus-Node deployment

Install the server, then install one or more `tdarr-node` releases that point at it.

```bash
helm install tdarr-server geekxflood/tdarr-server -n media
helm install tdarr-node-1 geekxflood/tdarr-node -n media \
  --set 'env[3].value=http://tdarr-server:8266' \
  --set 'env[4].value=tdarr-server' \
  --set 'env[5].value=8266'
```

## Persistence

| Mount path         | Toggle                | Purpose                                                                  |
| ------------------ | --------------------- | ------------------------------------------------------------------------ |
| `/app/server`      | `persistence.enabled` | Server database; also bind-mounts `/app/configs` via subPath `configs/`. |
| `/transcode_cache` | `nfsCache.enabled`    | Shared scratch cache. Use a dedicated `subPath` per server / node.       |

Mount your media library via `volumes` / `volumeMounts`.

## Integration notes

- The server Service exposes `webUIPort` (HTTP UI) and `serverPort` (node registration).
- Tdarr nodes connect to `serverIP=<release>.<namespace>` on `serverPort=8266`.
- Default env sets `internalNode=false` so this pod orchestrates only - run transcoding workers as separate `tdarr-node` releases.
- Share the transcode cache between server and nodes via a single NFS export with per-instance `subPath` to avoid `ReadWriteOnce` contention.

## Upgrading

```bash
helm repo update
helm upgrade tdarr-server geekxflood/tdarr-server -f values.yaml
```

## Uninstallation

```bash
helm uninstall tdarr-server
```

The server PVC is retained by Helm. Delete it manually to reclaim storage.

## Support

- Upstream: <https://home.tdarr.io/>
- Upstream issues: <https://github.com/HaveAGitGat/Tdarr/issues>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. Tdarr is distributed under the [GPL v3 license](https://github.com/HaveAGitGat/Tdarr).

# Tdarr Helm Chart

![Version: 1.4.1](https://img.shields.io/badge/Version-1.4.1-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 2.73.01](https://img.shields.io/badge/AppVersion-2.73.01-informational?style=flat-square)

A Helm chart for deploying [Tdarr](https://home.tdarr.io/) on Kubernetes. Tdarr is a distributed transcoding system for automating media library transcode and remux management, enforcing a consistent codec, container, and quality policy across libraries.

This chart deploys an all-in-one Tdarr pod that runs both the web UI / server and a co-located internal node, using the [haveagitgat/tdarr](https://github.com/HaveAGitGat/Tdarr) image. The web UI is exposed on port `8265` and node registration on port `8266`.

## Choosing the right Tdarr chart

This repository ships three related charts. Pick one based on topology:

| Chart                | Use when                                                                                                                                     |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `tdarr` (this chart) | Single pod, server plus an internal node. Simplest install. Put GPU here if you want hardware transcoding without separate node deployments. |
| `tdarr-server`       | Server / orchestrator only. Pair with one or more `tdarr-node` releases for horizontal scale. No GPU on the server.                          |
| `tdarr-node`         | Worker only. Connects back to a `tdarr-server`. Usually where GPUs live.                                                                     |

## Features

- All-in-one Tdarr server plus internal node in a single Deployment
- Optional NVIDIA GPU acceleration via `runtimeClassName` and `nvidia.com/gpu` resources
- Ingress and Gateway API `HTTPRoute` for exposing the web UI
- Three independent persistent volumes for server data, configs, and transcode cache
- Configurable liveness and readiness probes against the web UI
- Standard Kubernetes scheduling primitives: `nodeSelector`, `tolerations`, `affinity`

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- PersistentVolume provisioner if you enable persistence (recommended in production)
- For GPU transcoding: NVIDIA device plugin, the `nvidia` `RuntimeClass`, and CUDA-capable nodes
- For Gateway API: a Gateway implementation (Cilium, Istio, Envoy Gateway) and the `HTTPRoute` CRDs

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install tdarr geekxflood/tdarr
```

### Install with custom values

```bash
helm install tdarr geekxflood/tdarr -f values.yaml
```

## Configuration

### Core Parameters

| Parameter          | Description                                        | Default |
| ------------------ | -------------------------------------------------- | ------- |
| `enabled`          | Toggle the deployment (useful for umbrella charts) | `false` |
| `replicaCount`     | Number of pod replicas                             | `1`     |
| `nameOverride`     | Override chart name                                | `""`    |
| `fullnameOverride` | Override full resource name                        | `""`    |

### Image Parameters

| Parameter          | Description                                         | Default                     |
| ------------------ | --------------------------------------------------- | --------------------------- |
| `image.repository` | Tdarr image repository                              | `ghcr.io/haveagitgat/tdarr` |
| `image.pullPolicy` | Image pull policy                                   | `Always`                    |
| `image.tag`        | Image tag (defaults to chart `appVersion` if empty) | `""`                        |
| `imagePullSecrets` | Image pull secrets                                  | `[]`                        |

### Service Account

| Parameter                    | Description                       | Default |
| ---------------------------- | --------------------------------- | ------- |
| `serviceAccount.create`      | Create a dedicated ServiceAccount | `true`  |
| `serviceAccount.automount`   | Automount the SA token            | `true`  |
| `serviceAccount.annotations` | ServiceAccount annotations        | `{}`    |
| `serviceAccount.name`        | Override ServiceAccount name      | `""`    |

### Pod & Environment

| Parameter            | Description                                     | Default |
| -------------------- | ----------------------------------------------- | ------- |
| `podAnnotations`     | Pod annotations                                 | `{}`    |
| `podLabels`          | Pod labels                                      | `{}`    |
| `podSecurityContext` | Pod-level security context                      | `{}`    |
| `securityContext`    | Container security context                      | `{}`    |
| `env`                | Environment variables (list of `{name, value}`) | `[]`    |

Common env vars Tdarr accepts: `PUID`, `PGID`, `TZ`, `serverPort`, `webUIPort`, `internalNode`. See the [Tdarr docs](https://docs.tdarr.io/docs/installation/docker/run-flags) for the full reference.

### Service

| Parameter            | Description            | Default     |
| -------------------- | ---------------------- | ----------- |
| `service.type`       | Service type           | `ClusterIP` |
| `service.webUIPort`  | Web UI port            | `8265`      |
| `service.serverPort` | Node registration port | `8266`      |

### Ingress

| Parameter             | Description                   | Default |
| --------------------- | ----------------------------- | ------- |
| `ingress.enabled`     | Enable Ingress for the web UI | `false` |
| `ingress.className`   | Ingress class                 | `""`    |
| `ingress.annotations` | Ingress annotations           | `{}`    |
| `ingress.hosts`       | Ingress hosts                 | `[]`    |
| `ingress.tls`         | Ingress TLS config            | `[]`    |

### HTTPRoute (Gateway API)

| Parameter               | Description                                                              | Default |
| ----------------------- | ------------------------------------------------------------------------ | ------- |
| `httpRoute.enabled`     | Create a Gateway API `HTTPRoute`                                         | `false` |
| `httpRoute.annotations` | Route annotations                                                        | `{}`    |
| `httpRoute.labels`      | Route labels                                                             | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener references (required when enabled)                    | `[]`    |
| `httpRoute.hostnames`   | Hostnames matched by the route                                           | `[]`    |
| `httpRoute.rules`       | Route rules; defaults to this chart's Service when `backendRefs` omitted | `[]`    |

### GPU

| Parameter          | Description                                                                | Default  |
| ------------------ | -------------------------------------------------------------------------- | -------- |
| `gpu.enabled`      | Enable NVIDIA GPU support (sets `runtimeClassName`, injects GPU resources) | `false`  |
| `gpu.runtimeClass` | Pod `runtimeClassName` for GPU                                             | `nvidia` |
| `gpu.count`        | Number of GPUs to allocate                                                 | `1`      |

When GPU is enabled the chart sets `runtimeClassName`, injects `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=all`, and adds `nvidia.com/gpu` to both `limits` and `requests`, merging any user-provided values.

### Probes, Resources, Autoscaling

| Parameter             | Description                  | Default                                   |
| --------------------- | ---------------------------- | ----------------------------------------- |
| `livenessProbe`       | Liveness probe               | HTTP GET `/` on `8265`, 90s initial delay |
| `readinessProbe`      | Readiness probe              | HTTP GET `/` on `8265`, 60s initial delay |
| `resources`           | Pod resource requests/limits | `{}`                                      |
| `autoscaling.enabled` | Toggle HPA support           | `false`                                   |

### Persistence

This chart manages three independent PVCs. Enable only what you need.

| Parameter                         | Description                                | Default         |
| --------------------------------- | ------------------------------------------ | --------------- |
| `persistence.server.enabled`      | PVC mounted at `/app/server`               | `false`         |
| `persistence.server.size`         | Server data size                           | `20Gi`          |
| `persistence.server.storageClass` | StorageClass                               | `""`            |
| `persistence.server.accessMode`   | Access mode                                | `ReadWriteOnce` |
| `persistence.configs.enabled`     | PVC mounted at `/app/configs`              | `false`         |
| `persistence.configs.size`        | Configs size                               | `10Gi`          |
| `persistence.cache.enabled`       | PVC mounted at `/temp` (transcode scratch) | `false`         |
| `persistence.cache.size`          | Cache size                                 | `200Gi`         |
| `volumes`                         | Additional volumes (media libraries, etc.) | `[]`            |
| `volumeMounts`                    | Additional volume mounts                   | `[]`            |

### Scheduling

| Parameter      | Description     | Default |
| -------------- | --------------- | ------- |
| `nodeSelector` | Node selector   | `{}`    |
| `tolerations`  | Pod tolerations | `[]`    |
| `affinity`     | Affinity rules  | `{}`    |

## Examples

### CPU-only install with Ingress

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "100"
  - name: TZ
    value: "Europe/Zurich"

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: tdarr.example.com
      paths:
        - path: /
          pathType: Prefix

persistence:
  server:
    enabled: true
    size: 20Gi
  configs:
    enabled: true
    size: 10Gi
  cache:
    enabled: true
    size: 300Gi

volumes:
  - name: media
    persistentVolumeClaim:
      claimName: media-library

volumeMounts:
  - name: media
    mountPath: /media
```

### GPU install with NVIDIA runtime

```yaml
enabled: true

gpu:
  enabled: true
  runtimeClass: nvidia
  count: 1

resources:
  limits:
    cpu: "8"
    memory: "8Gi"
  requests:
    cpu: "2"
    memory: "2Gi"

nodeSelector:
  nvidia.com/gpu.present: "true"

persistence:
  server:
    enabled: true
  configs:
    enabled: true
  cache:
    enabled: true
    size: 500Gi
```

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

Cilium operators: `parentRefs[*].port` is ignored - use `sectionName` to target a listener. Cross-namespace `backendRefs` require a `ReferenceGrant` in the backend namespace.

## Persistence

The chart manages these mount points:

| Mount path     | Toggle                        | Purpose                                                                                         |
| -------------- | ----------------------------- | ----------------------------------------------------------------------------------------------- |
| `/app/server`  | `persistence.server.enabled`  | Tdarr database and server state. Lose this and Tdarr forgets your libraries.                    |
| `/app/configs` | `persistence.configs.enabled` | Flow / plugin configuration.                                                                    |
| `/temp`        | `persistence.cache.enabled`   | Transcode scratch space. Size to peak parallel jobs and source bitrate; 200-500 GiB is typical. |

Mount your media library separately via `volumes` / `volumeMounts`.

## Integration notes

- The internal node is enabled by default through the upstream image. Set `env.internalNode=false` and pair with `tdarr-node` releases for distributed transcoding.
- External nodes reach the server on the `server` port (`8266`) at `<release>-tdarr.<namespace>.svc.cluster.local`.
- Place GPUs on external `tdarr-node` releases rather than on this all-in-one pod if you want to scale workers independently.

## Upgrading

```bash
helm repo update
helm upgrade tdarr geekxflood/tdarr -f values.yaml
```

For destructive PVC changes (storage class, access mode), delete and recreate the release - PVCs are retained by Helm but not modified.

## Uninstallation

```bash
helm uninstall tdarr
```

PVCs are retained by default. Delete them manually if you want to reclaim storage.

## Support

- Upstream: <https://home.tdarr.io/>
- Upstream issues: <https://github.com/HaveAGitGat/Tdarr/issues>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. Tdarr is distributed under the [GPL v3 license](https://github.com/HaveAGitGat/Tdarr).

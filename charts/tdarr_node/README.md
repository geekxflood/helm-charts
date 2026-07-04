# Tdarr Node Helm Chart

![Version: 0.6.1](https://img.shields.io/badge/Version-0.6.1-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 2.73.01](https://img.shields.io/badge/AppVersion-2.73.01-informational?style=flat-square)

A Helm chart for deploying [Tdarr](https://home.tdarr.io/) worker nodes on Kubernetes. A Tdarr node is the worker process that performs transcoding and remuxing on behalf of a `tdarr-server`. Nodes are typically scheduled on GPU hosts so that hardware-accelerated transcoding stays close to the silicon.

This chart deploys workers from the [haveagitgat/tdarr_node](https://github.com/HaveAGitGat/Tdarr) image. Defaults assume an NVIDIA GPU is available - `runtimeClassName: nvidia` is enabled and `nvidia.com/gpu: 1` is requested.

If you want a single all-in-one pod (server plus internal node), use the [`tdarr`](https://github.com/geekxflood/helm-charts/tree/main/charts/tdarr) chart instead. If you need just the server / orchestrator, use [`tdarr-server`](https://github.com/geekxflood/helm-charts/tree/main/charts/tdarr_server).

## Features

- Stateless Tdarr worker that registers against a remote `tdarr-server`
- NVIDIA GPU support enabled by default (toggle via `runtime.enabled`)
- Configurable worker counts: `transcodegpuWorkers`, `transcodecpuWorkers`, `healthcheckgpuWorkers`, `healthcheckcpuWorkers`
- Shared NFS transcode cache with per-instance `subPath` to coexist with the server and other nodes
- Horizontal Pod Autoscaler toggle
- Standard scheduling primitives: `nodeSelector`, `tolerations`, `affinity`

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- A reachable `tdarr-server` (this chart, or any other Tdarr server)
- For GPU acceleration: NVIDIA device plugin, the `nvidia` `RuntimeClass`, CUDA-capable nodes
- For the shared cache pattern: an NFS export reachable from the cluster

This chart does **not** create a Service - nodes initiate outbound connections to the server.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install tdarr-node geekxflood/tdarr-node
```

### Install with custom values

```bash
helm install tdarr-node geekxflood/tdarr-node -f values.yaml
```

## Configuration

### Core Parameters

| Parameter          | Description                 | Default |
| ------------------ | --------------------------- | ------- |
| `replicaCount`     | Number of worker replicas   | `1`     |
| `nameOverride`     | Override chart name         | `""`    |
| `fullnameOverride` | Override full resource name | `""`    |

### Image

| Parameter          | Description                                         | Default                          |
| ------------------ | --------------------------------------------------- | -------------------------------- |
| `image.repository` | Tdarr node image                                    | `ghcr.io/haveagitgat/tdarr_node` |
| `image.pullPolicy` | Image pull policy                                   | `IfNotPresent`                   |
| `image.tag`        | Image tag (defaults to chart `appVersion` if empty) | `""`                             |
| `imagePullSecrets` | Image pull secrets                                  | `[]`                             |

### Service Account

| Parameter                    | Description             | Default |
| ---------------------------- | ----------------------- | ------- |
| `serviceAccount.create`      | Create a ServiceAccount | `true`  |
| `serviceAccount.automount`   | Automount the SA token  | `true`  |
| `serviceAccount.annotations` | SA annotations          | `{}`    |
| `serviceAccount.name`        | Override SA name        | `""`    |

### Environment & Worker Counts

The `env` list controls how the node connects to the server and how many workers it spawns.

| Variable                     | Description                                       | Default      |
| ---------------------------- | ------------------------------------------------- | ------------ |
| `PUID`                       | Process user id                                   | `1000`       |
| `PGID`                       | Process group id                                  | `100`        |
| `TZ`                         | Time zone                                         | `Etc/UTC`    |
| `nodeName`                   | Node display name                                 | `tdarr-node` |
| `serverURL`                  | Server base URL (e.g. `http://tdarr-server:8266`) | `""`         |
| `serverIP`                   | Server host (Service name or IP)                  | `""`         |
| `serverPort`                 | Server registration port                          | `8266`       |
| `transcodegpuWorkers`        | Concurrent GPU transcode workers                  | `4`          |
| `transcodecpuWorkers`        | Concurrent CPU transcode workers                  | `0`          |
| `healthcheckgpuWorkers`      | Concurrent GPU healthcheck workers                | `1`          |
| `healthcheckcpuWorkers`      | Concurrent CPU healthcheck workers                | `0`          |
| `NVIDIA_VISIBLE_DEVICES`     | GPU passthrough scope                             | `all`        |
| `NVIDIA_DRIVER_CAPABILITIES` | Driver capabilities                               | `all`        |

`envFrom` accepts entries shaped as `{type: secret|configmap, name: <ref>}`.

### Runtime (GPU)

| Parameter         | Description              | Default  |
| ----------------- | ------------------------ | -------- |
| `runtime.enabled` | Set `runtimeClassName`   | `true`   |
| `runtime.name`    | `runtimeClassName` value | `nvidia` |

### Resources

| Parameter   | Description                  | Default                    |
| ----------- | ---------------------------- | -------------------------- |
| `resources` | Resource requests and limits | `limits.nvidia.com/gpu: 1` |

Tune CPU / memory in your overlay. Keep at least one `nvidia.com/gpu` in `limits` when GPU workers are non-zero.

### Service / Ingress / HTTPRoute

Nodes do not serve HTTP traffic. The chart includes Service, Ingress and `HTTPRoute` templates for symmetry with the rest of the family, but the Service is **disabled by default** (`service.enabled: false`). Leave them off unless you have a specific reason to expose worker pods.

| Parameter           | Description      | Default |
| ------------------- | ---------------- | ------- |
| `service.enabled`   | Create Service   | `false` |
| `ingress.enabled`   | Create Ingress   | `false` |
| `httpRoute.enabled` | Create HTTPRoute | `false` |

### Probes

| Parameter        | Description     | Default                       |
| ---------------- | --------------- | ----------------------------- |
| `livenessProbe`  | Liveness probe  | `{}` (workers expose no HTTP) |
| `readinessProbe` | Readiness probe | `{}` (workers expose no HTTP) |

### Autoscaling

| Parameter                                       | Description     | Default |
| ----------------------------------------------- | --------------- | ------- |
| `autoscaling.enabled`                           | Enable HPA      | `false` |
| `autoscaling.minReplicas`                       | Min replicas    | `1`     |
| `autoscaling.maxReplicas`                       | Max replicas    | `100`   |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU %    | `80`    |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory % | `80`    |

### NFS Cache

| Parameter          | Description                                              | Default |
| ------------------ | -------------------------------------------------------- | ------- |
| `nfsCache.enabled` | Mount a shared NFS export at `/transcode_cache`          | `false` |
| `nfsCache.server`  | NFS server address                                       | `""`    |
| `nfsCache.path`    | NFS export path                                          | `""`    |
| `nfsCache.subPath` | Per-instance subPath (use unique value per node release) | `""`    |
| `volumes`          | Additional volumes (media library, etc.)                 | `[]`    |
| `volumeMounts`     | Additional volume mounts                                 | `[]`    |

### Scheduling

| Parameter      | Description     | Default |
| -------------- | --------------- | ------- |
| `nodeSelector` | Node selector   | `{}`    |
| `tolerations`  | Pod tolerations | `[]`    |
| `affinity`     | Affinity rules  | `{}`    |

## Examples

### GPU node connecting to an in-cluster server

```yaml
env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "100"
  - name: TZ
    value: "Etc/UTC"
  - name: nodeName
    value: "node-gpu-1"
  - name: serverURL
    value: "http://tdarr-server:8266"
  - name: serverIP
    value: "tdarr-server"
  - name: serverPort
    value: "8266"
  - name: transcodegpuWorkers
    value: "4"
  - name: transcodecpuWorkers
    value: "0"
  - name: healthcheckgpuWorkers
    value: "1"
  - name: healthcheckcpuWorkers
    value: "0"
  - name: NVIDIA_VISIBLE_DEVICES
    value: "all"
  - name: NVIDIA_DRIVER_CAPABILITIES
    value: "all"

runtime:
  enabled: true
  name: nvidia

resources:
  limits:
    cpu: "8"
    memory: "8Gi"
    nvidia.com/gpu: "1"
  requests:
    cpu: "2"
    memory: "2Gi"
    nvidia.com/gpu: "1"

nodeSelector:
  nvidia.com/gpu.present: "true"

nfsCache:
  enabled: true
  server: 192.0.2.10
  path: /exports/transcode
  subPath: node-gpu-1

volumes:
  - name: media
    persistentVolumeClaim:
      claimName: media-library

volumeMounts:
  - name: media
    mountPath: /media
```

### CPU-only node

```yaml
env:
  - name: nodeName
    value: "node-cpu-1"
  - name: serverURL
    value: "http://tdarr-server:8266"
  - name: serverIP
    value: "tdarr-server"
  - name: serverPort
    value: "8266"
  - name: transcodegpuWorkers
    value: "0"
  - name: transcodecpuWorkers
    value: "4"
  - name: healthcheckgpuWorkers
    value: "0"
  - name: healthcheckcpuWorkers
    value: "1"

runtime:
  enabled: false

resources:
  limits:
    cpu: "8"
    memory: "8Gi"
  requests:
    cpu: "2"
    memory: "2Gi"

nfsCache:
  enabled: true
  server: 192.0.2.10
  path: /exports/transcode
  subPath: node-cpu-1
```

### Multiple nodes in one cluster

Install the chart once per node identity, using unique `nodeName` and `nfsCache.subPath` values so each worker writes to its own scratch directory.

```bash
helm install tdarr-node-1 geekxflood/tdarr-node -n media -f node-1.yaml
helm install tdarr-node-2 geekxflood/tdarr-node -n media -f node-2.yaml
```

## Persistence

Nodes are stateless. Two volumes are commonly mounted:

| Mount path         | Source                     | Purpose                                                               |
| ------------------ | -------------------------- | --------------------------------------------------------------------- |
| `/transcode_cache` | `nfsCache` (NFS)           | Scratch space shared with server / other nodes. Use unique `subPath`. |
| `/media` (custom)  | `volumes` / `volumeMounts` | Source media library, typically RWX or read-only RWO.                 |

## Integration notes

- Nodes initiate connections to the server - no Ingress needed. They appear in the Tdarr UI's `Nodes` tab once they register.
- `serverIP` must resolve from inside the cluster. Use the Service DNS name of your `tdarr-server` release.
- `transcodegpuWorkers + healthcheckgpuWorkers` should not exceed the GPU capacity. Tune `nvidia.com/gpu` count accordingly when sharing devices with MIG / time-slicing.
- The chart's HPA toggles replicaCount, but most users prefer fixed replicas with one GPU per pod for predictable scheduling.

## Upgrading

```bash
helm repo update
helm upgrade tdarr-node geekxflood/tdarr-node -f values.yaml
```

Pods use the `Recreate` strategy - in-flight jobs will fail over to other nodes (or restart) on upgrade.

## Uninstallation

```bash
helm uninstall tdarr-node
```

## Support

- Upstream: <https://home.tdarr.io/>
- Upstream issues: <https://github.com/HaveAGitGat/Tdarr/issues>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. Tdarr is distributed under the [GPL v3 license](https://github.com/HaveAGitGat/Tdarr).

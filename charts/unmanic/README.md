# Unmanic Helm Chart

![Version: 0.3.1](https://img.shields.io/badge/Version-0.3.1-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 0.4.0](https://img.shields.io/badge/AppVersion-0.4.0-informational?style=flat-square)

A Helm chart for deploying [Unmanic](https://docs.unmanic.app/) on Kubernetes. Unmanic is a library optimizer that scans your media collection, applies user-defined plugins (transcoding, remuxing, codec normalization), and keeps your library converging on a standard format. It uses the [josh5/unmanic](https://hub.docker.com/r/josh5/unmanic) image.

## Features

- Single-pod Unmanic deployment with web UI on port `8888`
- Optional NVIDIA GPU support via a configurable `runtimeClassName`
- Ingress and Gateway API `HTTPRoute` for exposing the UI
- HPA toggle and configurable HTTP probes
- Bring-your-own volumes for library, cache, and config

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- PersistentVolumes for the media library and Unmanic config (recommended)
- For GPU transcoding: NVIDIA device plugin, a `RuntimeClass` (commonly `nvidia`), CUDA-capable nodes
- For Gateway API: a Gateway controller (Cilium, Istio, Envoy Gateway) and `HTTPRoute` CRDs

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install unmanic geekxflood/unmanic
```

### Install with custom values

```bash
helm install unmanic geekxflood/unmanic -f values.yaml
```

## Configuration

### Core Parameters

| Parameter          | Description                   | Default |
| ------------------ | ----------------------------- | ------- |
| `replicaCount`     | Number of replicas (keep `1`) | `1`     |
| `nameOverride`     | Override chart name           | `""`    |
| `fullnameOverride` | Override full resource name   | `""`    |

### Image

| Parameter          | Description                                         | Default         |
| ------------------ | --------------------------------------------------- | --------------- |
| `image.repository` | Unmanic image repository                            | `josh5/unmanic` |
| `image.pullPolicy` | Image pull policy                                   | `IfNotPresent`  |
| `image.tag`        | Image tag (defaults to chart `appVersion` if empty) | `""`            |
| `imagePullSecrets` | Image pull secrets                                  | `[]`            |

### Service Account

| Parameter                    | Description             | Default |
| ---------------------------- | ----------------------- | ------- |
| `serviceAccount.create`      | Create a ServiceAccount | `true`  |
| `serviceAccount.automount`   | Automount SA token      | `true`  |
| `serviceAccount.annotations` | SA annotations          | `{}`    |
| `serviceAccount.name`        | Override SA name        | `""`    |

### Pod & Environment

| Parameter            | Description                           | Default |
| -------------------- | ------------------------------------- | ------- |
| `podAnnotations`     | Pod annotations                       | `{}`    |
| `podLabels`          | Pod labels                            | `{}`    |
| `podSecurityContext` | Pod security context                  | `{}`    |
| `securityContext`    | Container security context            | `{}`    |
| `env`                | Env vars (list of `{name, value}`)    | `[]`    |
| `envFrom`            | Env from `secret`/`configmap` refs    | `[]`    |
| `runtime.enabled`    | Set `runtimeClassName` (e.g. for GPU) | `false` |
| `runtime.name`       | `runtimeClassName` value              | `""`    |

Common Unmanic env vars: `PUID`, `PGID`, `TZ`. Set `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=all` when using GPU.

### Service

| Parameter      | Description  | Default     |
| -------------- | ------------ | ----------- |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8888`      |

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
| `httpRoute.hostnames`   | Hostnames matched                                  | `[]`    |
| `httpRoute.rules`       | Route rules; defaults to this Service when omitted | `[]`    |

### Probes, Resources, Autoscaling

| Parameter                                       | Description     | Default                           |
| ----------------------------------------------- | --------------- | --------------------------------- |
| `livenessProbe`                                 | Liveness probe  | HTTP GET `/` on named port `http` |
| `readinessProbe`                                | Readiness probe | HTTP GET `/` on named port `http` |
| `resources`                                     | Resource specs  | `{}`                              |
| `autoscaling.enabled`                           | Enable HPA      | `false`                           |
| `autoscaling.minReplicas`                       | Min replicas    | `1`                               |
| `autoscaling.maxReplicas`                       | Max replicas    | `100`                             |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU %    | `80`                              |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory % | `80`                              |

### Storage & Scheduling

| Parameter      | Description              | Default |
| -------------- | ------------------------ | ------- |
| `volumes`      | Additional volumes       | `[]`    |
| `volumeMounts` | Additional volume mounts | `[]`    |
| `nodeSelector` | Node selector            | `{}`    |
| `tolerations`  | Pod tolerations          | `[]`    |
| `affinity`     | Affinity rules           | `{}`    |

## Examples

### CPU-only install with Ingress

```yaml
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
    - host: unmanic.example.com
      paths:
        - path: /
          pathType: Prefix

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: unmanic-config
  - name: library
    persistentVolumeClaim:
      claimName: media-library
  - name: cache
    emptyDir:
      sizeLimit: 100Gi

volumeMounts:
  - name: config
    mountPath: /config
  - name: library
    mountPath: /library
  - name: cache
    mountPath: /tmp/unmanic
```

### GPU install with NVIDIA runtime

```yaml
env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "100"
  - name: TZ
    value: "Europe/Zurich"
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

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: unmanic-config
  - name: library
    persistentVolumeClaim:
      claimName: media-library

volumeMounts:
  - name: config
    mountPath: /config
  - name: library
    mountPath: /library
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
    - unmanic.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1
```

Cilium operators: `parentRefs[*].port` is ignored - use `sectionName`. Cross-namespace `backendRefs` need a `ReferenceGrant`.

## Persistence

The chart does not provision PVCs for you - declare them in `volumes` / `volumeMounts`. Typical mounts:

| Mount path     | Purpose                                                      |
| -------------- | ------------------------------------------------------------ |
| `/config`      | Unmanic configuration, plugin state, task database           |
| `/library`     | Source media to optimize                                     |
| `/tmp/unmanic` | Working scratch directory (size to peak parallel transcodes) |

## Integration notes

- Unmanic is standalone - no auxiliary services required. Plugins handle codec / container normalization on-disk.
- If you want a distributed transcoder family instead, see the [`tdarr`](https://github.com/geekxflood/helm-charts/tree/main/charts/tdarr) charts.

## Upgrading

```bash
helm repo update
helm upgrade unmanic geekxflood/unmanic -f values.yaml
```

## Uninstallation

```bash
helm uninstall unmanic
```

Bring-your-own PVCs are untouched by uninstall.

## Support

- Upstream docs: <https://docs.unmanic.app/>
- Upstream issues: <https://github.com/Unmanic/unmanic/issues>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. Unmanic is distributed under the [GPL v3 license](https://github.com/Unmanic/unmanic/blob/master/LICENSE).

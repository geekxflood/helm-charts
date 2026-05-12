# Whisper ASR Helm Chart

![Version: 1.3.0](https://img.shields.io/badge/Version-1.3.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.6.1-gpu](https://img.shields.io/badge/AppVersion-1.6.1--gpu-informational?style=flat-square)

A Helm chart for deploying the [OpenAI Whisper ASR Webservice](https://github.com/ahmetoner/whisper-asr-webservice) on Kubernetes. This service wraps OpenAI's Whisper model behind a REST API, designed to be consumed by clients like Bazarr (subtitle generation) or any custom integration that needs automatic speech recognition.

This chart deploys the [onerahmet/openai-whisper-asr-webservice](https://hub.docker.com/r/onerahmet/openai-whisper-asr-webservice) image and exposes a REST API on port `9000` with interactive Swagger docs at `/docs`.

## Features

- Three selectable ASR engines: `openai_whisper`, `faster_whisper`, `whisperx`
- Configurable model size from `tiny` to `large-v3`
- CPU or GPU (CUDA) inference; optional NVIDIA GPU support via `runtimeClassName`
- Persistent model cache to avoid re-downloading on restart
- Optional Cloudflare Tunnel binding for zero-trust external access
- Ingress and Gateway API `HTTPRoute` for HTTP exposure
- Horizontal Pod Autoscaler toggle
- Long-tolerance probes that survive cold-start model downloads

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- PersistentVolume provisioner (strongly recommended; models are 75 MB to 3+ GB each)
- For GPU acceleration: NVIDIA device plugin, the `nvidia` `RuntimeClass`, CUDA-capable nodes, and the `*-gpu` image tag
- For Gateway API: a Gateway controller (Cilium, Istio, Envoy Gateway) and `HTTPRoute` CRDs
- For Cloudflare Tunnel: `cloudflare-operator` and a `Tunnel`/`ClusterTunnel` resource

GPU is **strongly recommended** for `medium` and larger models. CPU inference of the `large` model on real-world audio is impractical for interactive use.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install whisper geekxflood/whisper
```

### Install with custom values

```bash
helm install whisper geekxflood/whisper -f values.yaml
```

## Configuration

### Core Parameters

| Parameter          | Description                  | Default |
| ------------------ | ---------------------------- | ------- |
| `enabled`          | Toggle the deployment        | `false` |
| `replicaCount`     | Number of replicas           | `1`     |
| `nameOverride`     | Override chart name          | `""`    |
| `fullnameOverride` | Override full resource name  | `""`    |

### Image

| Parameter          | Description                                                              | Default                                  |
| ------------------ | ------------------------------------------------------------------------ | ---------------------------------------- |
| `image.repository` | Whisper webservice image                                                 | `onerahmet/openai-whisper-asr-webservice` |
| `image.pullPolicy` | Image pull policy                                                        | `IfNotPresent`                           |
| `image.tag`        | Image tag - use `latest` for CPU or a `-gpu` tag (e.g. `latest-gpu`)     | `latest`                                 |
| `imagePullSecrets` | Image pull secrets                                                       | `[]`                                     |

### Service Account

| Parameter                    | Description             | Default |
| ---------------------------- | ----------------------- | ------- |
| `serviceAccount.create`      | Create a ServiceAccount | `false` |
| `serviceAccount.automount`   | Automount SA token      | `true`  |
| `serviceAccount.annotations` | SA annotations          | `{}`    |
| `serviceAccount.name`        | Override SA name        | `""`    |

### Whisper / ASR

| Parameter                  | Description                                                                  | Default          |
| -------------------------- | ---------------------------------------------------------------------------- | ---------------- |
| `whisper.asrEngine`        | Engine: `openai_whisper`, `faster_whisper`, `whisperx`                       | `faster_whisper` |
| `whisper.asrModel`         | Model size: `tiny`, `base`, `small`, `medium`, `large`, `large-v2`, `large-v3` | `base`         |
| `whisper.asrDevice`        | Device: `cpu` or `cuda`                                                      | `cpu`            |
| `whisper.asrModelPath`     | Custom model path (optional)                                                 | `""`             |
| `whisper.modelIdleTimeout` | Seconds before unloading idle model from memory                              | `"300"`          |
| `whisper.extraEnv`         | Additional environment variables                                             | `[]`             |

### GPU

| Parameter          | Description                                  | Default          |
| ------------------ | -------------------------------------------- | ---------------- |
| `gpu.enabled`      | Enable GPU support (sets `runtimeClassName`) | `false`          |
| `gpu.runtimeClass` | Pod `runtimeClassName`                       | `nvidia`         |
| `gpu.count`        | Number of GPUs to allocate                   | `1`              |
| `gpu.type`         | Resource key used for the request            | `nvidia.com/gpu` |

When `gpu.enabled` is true the chart sets `runtimeClassName`, injects `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=all`, and adds `gpu.type: gpu.count` to both `limits` and `requests` (merging any user-provided `resources.limits` / `resources.requests`). Set `whisper.asrDevice: cuda` and use a `*-gpu` image tag to actually use the GPU.

### Service

| Parameter             | Description         | Default     |
| --------------------- | ------------------- | ----------- |
| `service.type`        | Service type        | `ClusterIP` |
| `service.port`        | Service port        | `9000`      |
| `service.annotations` | Service annotations | `{}`        |

### Ingress

| Parameter             | Description         | Default |
| --------------------- | ------------------- | ------- |
| `ingress.enabled`     | Enable Ingress      | `false` |
| `ingress.className`   | Ingress class       | `""`    |
| `ingress.annotations` | Ingress annotations | `{}`    |
| `ingress.hosts`       | Ingress hosts       | `[]`    |
| `ingress.tls`         | Ingress TLS         | `[]`    |

### HTTPRoute (Gateway API)

| Parameter               | Description                                          | Default |
| ----------------------- | ---------------------------------------------------- | ------- |
| `httpRoute.enabled`     | Create a Gateway API `HTTPRoute`                     | `false` |
| `httpRoute.annotations` | Route annotations                                    | `{}`    |
| `httpRoute.labels`      | Route labels                                         | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener references                        | `[]`    |
| `httpRoute.hostnames`   | Hostnames matched                                    | `[]`    |
| `httpRoute.rules`       | Route rules; defaults to this Service when omitted   | `[]`    |

### Cloudflare Tunnel

| Parameter            | Description                                       | Default |
| -------------------- | ------------------------------------------------- | ------- |
| `cfTunnel.enabled`   | Create a `TunnelBinding` for Cloudflare Tunnel    | `false` |
| `cfTunnel.tunnelRef` | Reference to the `Tunnel` / `ClusterTunnel` CR    | `{}`    |
| `cfTunnel.subjects`  | Tunnel subjects (FQDN / protocol per Service)     | `[]`    |

### Persistence (Model Cache)

| Parameter                   | Description                                                       | Default         |
| --------------------------- | ----------------------------------------------------------------- | --------------- |
| `persistence.enabled`       | Create a PVC mounted at `persistence.mountPath`                   | `false`         |
| `persistence.existingClaim` | Use an existing PVC instead of creating one                       | `""`            |
| `persistence.storageClass`  | StorageClass                                                      | `""`            |
| `persistence.accessMode`    | Access mode                                                       | `ReadWriteOnce` |
| `persistence.size`          | PVC size                                                          | `10Gi`          |
| `persistence.mountPath`     | Mount path for the Whisper model cache                            | `/root/.cache`  |
| `volumes`                   | Additional volumes                                                | `[]`            |
| `volumeMounts`              | Additional volume mounts                                          | `[]`            |

### Probes, Resources, Autoscaling

| Parameter                                    | Description     | Default                                          |
| -------------------------------------------- | --------------- | ------------------------------------------------ |
| `livenessProbe`                              | Liveness probe  | HTTP GET `/` on `http`, 600s initial delay       |
| `readinessProbe`                             | Readiness probe | HTTP GET `/` on `http`, 120s initial delay       |
| `resources`                                  | Resource specs  | `{}`                                             |
| `autoscaling.enabled`                        | Enable HPA      | `false`                                          |
| `autoscaling.minReplicas`                    | Min replicas    | `1`                                              |
| `autoscaling.maxReplicas`                    | Max replicas    | `3`                                              |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU %    | `80`                                             |

### Scheduling

| Parameter      | Description     | Default |
| -------------- | --------------- | ------- |
| `nodeSelector` | Node selector   | `{}`    |
| `tolerations`  | Pod tolerations | `[]`    |
| `affinity`     | Affinity rules  | `{}`    |

## Examples

### CPU-only install with `faster_whisper` base

```yaml
enabled: true

image:
  repository: onerahmet/openai-whisper-asr-webservice
  tag: latest

whisper:
  asrEngine: faster_whisper
  asrModel: base
  asrDevice: cpu

persistence:
  enabled: true
  size: 5Gi

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: whisper.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: "4"
    memory: "8Gi"
  requests:
    cpu: "1"
    memory: "2Gi"
```

### GPU install with `large-v3`

```yaml
enabled: true

image:
  repository: onerahmet/openai-whisper-asr-webservice
  tag: latest-gpu

whisper:
  asrEngine: faster_whisper
  asrModel: large-v3
  asrDevice: cuda
  modelIdleTimeout: "300"

gpu:
  enabled: true
  runtimeClass: nvidia
  count: 1
  type: nvidia.com/gpu

resources:
  limits:
    cpu: "8"
    memory: "16Gi"
  requests:
    cpu: "2"
    memory: "4Gi"

nodeSelector:
  nvidia.com/gpu.present: "true"

persistence:
  enabled: true
  size: 20Gi
  mountPath: /root/.cache
```

### Cloudflare Tunnel exposure

```yaml
enabled: true

cfTunnel:
  enabled: true
  tunnelRef:
    name: home-cluster
    kind: ClusterTunnel
  subjects:
    - name: whisper
      spec:
        fqdn: whisper.example.com
        protocol: http
```

### Gateway API HTTPRoute

```yaml
enabled: true

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - whisper.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1
```

### Model size guidance

| Model      | Disk    | VRAM (float16) | Notes                                      |
| ---------- | ------- | -------------- | ------------------------------------------ |
| `tiny`     | ~75 MB  | ~1 GB          | Fast, lowest accuracy                      |
| `base`     | ~150 MB | ~1 GB          | Good CPU default                           |
| `small`    | ~480 MB | ~2 GB          | Decent CPU; usable on modest GPUs          |
| `medium`   | ~1.5 GB | ~5 GB          | GPU strongly recommended                   |
| `large-v3` | ~3 GB   | ~10 GB         | Best accuracy; needs a serious GPU         |

## Persistence

Whisper caches downloaded models under `/root/.cache`. Without persistence the cache is lost on every pod restart and the model is re-downloaded - 3+ GB and several minutes of warm-up for `large-v3`. Enable `persistence.enabled` (or supply `persistence.existingClaim`) in any non-throwaway deployment.

## Integration notes

- **Bazarr**: configure Whisper as a provider in Bazarr (`Settings -> Subtitles -> Providers -> Whisper`). Point it at the in-cluster Service URL (`http://whisper.<namespace>.svc.cluster.local:9000`). Bazarr will POST audio and receive subtitle output.
- **Probes are intentionally long** (600s liveness, 120s readiness) because the first request after model load can block for minutes. Increase them further if you preload `large-v3` without a warm cache.
- **HPA caution**: each replica must download and load the model independently. For sustained workloads, prefer a fixed replica count over autoscaling.
- For an embedded all-in-one alternative that ships its own Whisper, see [`subgen`](https://github.com/geekxflood/helm-charts/tree/main/charts/subgen).

## Upgrading

```bash
helm repo update
helm upgrade whisper geekxflood/whisper -f values.yaml
```

Bumping the chart `appVersion` may switch between CPU and GPU image variants - keep `image.tag` aligned with your hardware.

## Uninstallation

```bash
helm uninstall whisper
```

The model cache PVC is retained. Delete it manually to reclaim storage.

## Support

- Upstream: <https://github.com/ahmetoner/whisper-asr-webservice>
- Upstream issues: <https://github.com/ahmetoner/whisper-asr-webservice/issues>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. The Whisper ASR webservice is distributed under the [MIT license](https://github.com/ahmetoner/whisper-asr-webservice/blob/main/LICENCE). OpenAI Whisper is also MIT-licensed.

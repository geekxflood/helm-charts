# SubGen Helm Chart

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 2024.12.1](https://img.shields.io/badge/AppVersion-2024.12.1-informational?style=flat-square)

A Helm chart for deploying [SubGen](https://github.com/McCloudS/subgen) on Kubernetes. SubGen auto-generates subtitles for your media library using OpenAI Whisper. It listens for webhooks from media servers (Plex, Jellyfin, Emby, Bazarr) and produces subtitle files inline with your library.

This chart deploys the [mccloud/subgen](https://hub.docker.com/r/mccloud/subgen) image. The container ships its own Whisper runtime - SubGen does not depend on the [Whisper webservice chart](https://github.com/geekxflood/helm-charts/tree/main/charts/whisper), though both can coexist.

## Features

- Webhook listener on port `9000` for media-server post-processing hooks
- Configurable Whisper model size (`tiny` through `large-v3-turbo`) and compute type
- CPU or CUDA execution mode
- Optional NVIDIA GPU support via `runtimeClassName` and `nvidia.com/gpu` resources
- Persistent model cache to avoid re-downloading on every restart
- Ingress for webhook exposure
- Configurable concurrency: `CONCURRENT_TRANSCRIPTIONS`, `WHISPER_THREADS`

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- A PersistentVolume provisioner (strongly recommended; Whisper models are 75 MB to 3+ GB each)
- For GPU acceleration: NVIDIA device plugin, the `nvidia` `RuntimeClass`, CUDA-capable nodes
- Read/write access to your media library from the SubGen pod (mounted via `volumes`)

GPU is **strongly recommended** for any model larger than `base` - CPU transcription of a 90-minute video on the `large` model takes hours.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install subgen geekxflood/subgen
```

### Install with custom values

```bash
helm install subgen geekxflood/subgen -f values.yaml
```

## Configuration

### Core Parameters

| Parameter          | Description                   | Default |
| ------------------ | ----------------------------- | ------- |
| `replicaCount`     | Number of replicas (keep `1`) | `1`     |
| `nameOverride`     | Override chart name           | `""`    |
| `fullnameOverride` | Override full resource name   | `""`    |

### Image

| Parameter          | Description       | Default          |
| ------------------ | ----------------- | ---------------- |
| `image.repository` | SubGen image      | `mccloud/subgen` |
| `image.tag`        | Image tag         | `latest`         |
| `image.pullPolicy` | Image pull policy | `IfNotPresent`   |

### Whisper Configuration

| Parameter                       | Description                                                                                      | Default      |
| ------------------------------- | ------------------------------------------------------------------------------------------------ | ------------ |
| `env.WHISPER_MODEL`             | Model size: `tiny`, `base`, `small`, `medium`, `large`, `large-v2`, `large-v3`, `large-v3-turbo` | `base`       |
| `env.WHISPER_THREADS`           | Whisper worker threads (CPU)                                                                     | `"4"`        |
| `env.COMPUTE_TYPE`              | Precision: `float16`, `int8`, `int8_float16`, `int8_bfloat16`                                    | `float16`    |
| `env.DEVICE`                    | Inference device: `cpu` or `cuda`                                                                | `cpu`        |
| `env.CLEAR_VRAM_ON_COMPLETE`    | Unload model from VRAM after each job                                                            | `"True"`     |
| `env.TRANSCRIBE_OR_TRANSLATE`   | `transcribe` (same language) or `translate` (to English)                                         | `transcribe` |
| `env.PROCADDEDMEDIA`            | Process media added after SubGen started                                                         | `"True"`     |
| `env.SUBGEN_DELETE_ORIGINAL`    | Delete pre-existing subtitle files before regenerating                                           | `"False"`    |
| `env.CONCURRENT_TRANSCRIPTIONS` | How many files SubGen will transcribe in parallel                                                | `"2"`        |
| `env.WEBHOOK_PORT`              | HTTP port for webhook receiver                                                                   | `"9000"`     |
| `env.DEBUG`                     | Enable debug logging                                                                             | `"False"`    |

Setting `env.DEVICE: "cuda"` automatically injects `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=all`.

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

### GPU / Runtime

| Parameter          | Description                                           | Default |
| ------------------ | ----------------------------------------------------- | ------- |
| `runtimeClassName` | Pod `runtimeClassName` (set to `nvidia` for GPU)      | `""`    |
| `resources`        | Resource requests / limits (include `nvidia.com/gpu`) | `{}`    |
| `nodeSelector`     | Node selector (e.g. `nvidia.com/gpu.present: "true"`) | `{}`    |

GPU is not wired through a dedicated `gpu.*` block - configure it explicitly via `runtimeClassName`, `resources.limits."nvidia.com/gpu"`, and `nodeSelector`. See the GPU example below.

### Persistence (Model Cache)

| Parameter                  | Description                                     | Default         |
| -------------------------- | ----------------------------------------------- | --------------- |
| `persistence.enabled`      | Create a PVC mounted at `persistence.mountPath` | `false`         |
| `persistence.storageClass` | StorageClass (empty = cluster default)          | `""`            |
| `persistence.accessMode`   | Access mode                                     | `ReadWriteOnce` |
| `persistence.size`         | PVC size                                        | `10Gi`          |
| `persistence.mountPath`    | Mount path for the Whisper model cache          | `/root/.cache`  |

Enable persistence in production. Without it, every pod restart re-downloads the selected model (up to ~3 GB for `large-v3`).

### Probes & Scheduling

| Parameter         | Description      | Default                                          |
| ----------------- | ---------------- | ------------------------------------------------ |
| `livenessProbe`   | Liveness probe   | HTTP GET `/status` on `http`, 300s initial delay |
| `readinessProbe`  | Readiness probe  | HTTP GET `/status` on `http`, 60s initial delay  |
| `securityContext` | Security context | `{}`                                             |
| `tolerations`     | Pod tolerations  | `[]`                                             |
| `affinity`        | Affinity rules   | `{}`                                             |

Long initial delays cover first-run model downloads.

## Examples

### CPU-only install (small model)

```yaml
env:
  WHISPER_MODEL: "base"
  COMPUTE_TYPE: "int8"
  DEVICE: "cpu"
  CONCURRENT_TRANSCRIPTIONS: "1"
  WEBHOOK_PORT: "9000"

persistence:
  enabled: true
  size: 5Gi
  mountPath: /root/.cache

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: subgen.example.com
      paths:
        - path: /
          pathType: Prefix

volumes:
  - name: media
    persistentVolumeClaim:
      claimName: media-library

volumeMounts:
  - name: media
    mountPath: /tv
    readOnly: false
```

> `volumes` and `volumeMounts` are not first-class keys in this chart - mount media via the deployment's pod spec or use a values override that injects them. To bind media into SubGen, fork the chart or use a custom Kustomize overlay.

### GPU install with `large-v3-turbo`

```yaml
env:
  WHISPER_MODEL: "large-v3-turbo"
  COMPUTE_TYPE: "float16"
  DEVICE: "cuda"
  CLEAR_VRAM_ON_COMPLETE: "True"
  CONCURRENT_TRANSCRIPTIONS: "2"
  WEBHOOK_PORT: "9000"

runtimeClassName: nvidia

resources:
  limits:
    cpu: "8"
    memory: "16Gi"
    nvidia.com/gpu: "1"
  requests:
    cpu: "2"
    memory: "4Gi"
    nvidia.com/gpu: "1"

nodeSelector:
  nvidia.com/gpu.present: "true"

persistence:
  enabled: true
  size: 15Gi
  mountPath: /root/.cache
```

### Model size guidance

| Model            | Disk    | VRAM (float16) | Notes                                       |
| ---------------- | ------- | -------------- | ------------------------------------------- |
| `tiny`           | ~75 MB  | ~1 GB          | Fast, low accuracy                          |
| `base`           | ~150 MB | ~1 GB          | Good CPU default                            |
| `small`          | ~480 MB | ~2 GB          | Decent CPU performance                      |
| `medium`         | ~1.5 GB | ~5 GB          | Needs GPU for real-time                     |
| `large-v3`       | ~3 GB   | ~10 GB         | Best accuracy                               |
| `large-v3-turbo` | ~1.6 GB | ~6 GB          | Best speed/accuracy tradeoff on modern GPUs |

## Persistence

SubGen caches downloaded Whisper models under `/root/.cache`. Without persistence the cache is lost on every pod restart - enable `persistence.enabled` and size for your model footprint (5-20 GiB is plenty for one model, more if you switch models often).

## Integration notes

- **Bazarr** is the most common front-end. Configure it to use the SubGen webhook (`http://subgen:9000/`) via a custom provider, or rely on SubGen's filesystem watchers if media is mounted directly into the pod.
- **Plex / Jellyfin / Emby**: send a post-scan webhook to `http://subgen:9000/` so SubGen can grab the file path and process it.
- **Whisper webservice (separate chart)**: SubGen embeds Whisper directly and does not need the standalone `whisper` chart. Use the `whisper` chart only when Bazarr needs a generic Whisper provider.
- For library access, SubGen needs read/write on the media files (subtitles are written next to the source).

## Upgrading

```bash
helm repo update
helm upgrade subgen geekxflood/subgen -f values.yaml
```

When changing `WHISPER_MODEL`, the new model is downloaded on next start - keep the cache PVC if you want to retain previous models too.

## Uninstallation

```bash
helm uninstall subgen
```

The model cache PVC is retained by Helm. Delete it manually if you want to free storage.

## Support

- Upstream: <https://github.com/McCloudS/subgen>
- Upstream issues: <https://github.com/McCloudS/subgen/issues>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. SubGen is distributed under the [MIT license](https://github.com/McCloudS/subgen/blob/main/LICENSE). OpenAI Whisper is also MIT-licensed.

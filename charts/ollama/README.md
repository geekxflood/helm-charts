# Ollama Helm Chart

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 0.4.6](https://img.shields.io/badge/AppVersion-0.4.6-informational?style=flat-square)

A Helm chart for deploying [Ollama](https://ollama.com/) on Kubernetes. Ollama is a local runtime for large language models - it pulls model weights from a registry, exposes an OpenAI-compatible REST API on port `11434`, and manages model lifecycle (load, unload, quantize) on the underlying GPU or CPU.

This chart deploys the official [ollama/ollama](https://hub.docker.com/r/ollama/ollama) image. GPU is enabled by default - models run dramatically better on GPU, and the chart presumes that's where you want them.

Pair with [Open WebUI](https://github.com/geekxflood/helm-charts/tree/main/charts/open-webui) for a chat front-end.

## Features

- Local LLM runtime with GPU acceleration enabled by default
- Optional **model preloading**: list models in `values.models` and they are pulled by an init container before the main pod is ready
- Persistent model storage with sensible 100 GiB default - real workloads need much more
- OpenAI-compatible REST API on port `11434`
- Optional Ingress (most users front Ollama with Open WebUI on the cluster network)
- Configurable resource limits, node selector, and tolerations for GPU placement

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- PersistentVolume provisioner (model storage is enabled by default)
- For GPU acceleration (default): NVIDIA device plugin, the `nvidia` `RuntimeClass`, and CUDA-capable nodes labelled `nvidia.com/gpu.present=true`
- Enough disk under the model PVC to hold every model you intend to pull

## Storage sizing - read this first

Ollama caches every pulled model under `/root/.ollama`. Sizes vary wildly by model and quantization:

| Model                  | Approx. size on disk |
| ---------------------- | -------------------- |
| `llama3:8b`            | ~4.7 GB              |
| `llama3:70b`           | ~40 GB               |
| `mistral:7b`           | ~4.1 GB              |
| `mixtral:8x7b`         | ~26 GB               |
| `codellama:34b`        | ~19 GB               |
| `llama3.1:405b`        | ~230 GB              |
| `nomic-embed-text`     | ~270 MB              |

The default PVC is `100Gi`. That holds a handful of mid-size models. **Increase `persistence.size` before you install** if you plan to hoard models - resizing later requires storage class support and is more work than getting it right up front. For a 70B-or-larger workflow, plan on `250Gi` to `500Gi`.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install ollama geekxflood/ollama
```

### Install with custom values

```bash
helm install ollama geekxflood/ollama -f values.yaml
```

## Configuration

### Core Parameters

| Parameter      | Description        | Default |
| -------------- | ------------------ | ------- |
| `replicaCount` | Number of replicas | `1`     |

Ollama uses local PVC storage and a `Recreate` strategy - keep `replicaCount` at `1` unless every replica gets its own PVC.

### Image

| Parameter          | Description       | Default        |
| ------------------ | ----------------- | -------------- |
| `image.repository` | Ollama image      | `ollama/ollama` |
| `image.tag`        | Image tag         | `latest`       |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Model Preloading

| Parameter | Description                                                                                         | Default |
| --------- | --------------------------------------------------------------------------------------------------- | ------- |
| `models`  | List of model names to `ollama pull` from an init container before the main container starts       | `[]`    |

Example: `models: ["llama3:8b", "nomic-embed-text"]`. The init container reuses the same image and shares the persistence volume so pulls land in the right place. Long pulls can extend pod startup time considerably.

### Environment & Service Account

| Parameter                    | Description                                | Default |
| ---------------------------- | ------------------------------------------ | ------- |
| `env`                        | Additional env vars (list of `{name, value}`) | `[]` |
| `podAnnotations`             | Pod annotations                            | `{}`    |
| `securityContext`            | Container security context                 | `{}`    |
| `serviceAccount.create`      | Create a ServiceAccount                    | `true`  |
| `serviceAccount.name`        | Override SA name                           | `""`    |
| `serviceAccount.annotations` | SA annotations                             | `{}`    |

Common Ollama env vars: `OLLAMA_DEBUG`, `OLLAMA_HOST`, `OLLAMA_NUM_PARALLEL`, `OLLAMA_MAX_LOADED_MODELS`, `OLLAMA_KEEP_ALIVE`. See the [upstream env reference](https://github.com/ollama/ollama/blob/main/docs/faq.md).

### Service

| Parameter             | Description         | Default     |
| --------------------- | ------------------- | ----------- |
| `service.type`        | Service type        | `ClusterIP` |
| `service.port`        | Service port        | `11434`     |
| `service.annotations` | Service annotations | `{}`        |

### GPU

| Parameter          | Description                                              | Default  |
| ------------------ | -------------------------------------------------------- | -------- |
| `gpu.enabled`      | Enable GPU support (sets `runtimeClassName`, GPU resources) | `true` |
| `gpu.runtimeClass` | Pod `runtimeClassName`                                   | `nvidia` |
| `gpu.count`        | Number of GPUs to allocate                               | `1`      |

When GPU is enabled the chart sets `runtimeClassName`, injects `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=all`, and adds `nvidia.com/gpu: <count>` to both `limits` and `requests`. The optional model-pull init container inherits the same GPU configuration.

### Resources

| Parameter   | Description           | Default                                       |
| ----------- | --------------------- | --------------------------------------------- |
| `resources` | Resource requests/limits | `limits: cpu=8, memory=32Gi`; `requests: cpu=2, memory=8Gi` |

Increase memory and CPU for large models (`70b` and up).

### Persistence (Models)

| Parameter                  | Description                                       | Default         |
| -------------------------- | ------------------------------------------------- | --------------- |
| `persistence.enabled`      | Create a PVC for the model cache                  | `true`          |
| `persistence.storageClass` | StorageClass                                      | `""`            |
| `persistence.accessMode`   | Access mode                                       | `ReadWriteOnce` |
| `persistence.size`         | PVC size - see "Storage sizing" above             | `100Gi`         |
| `persistence.mountPath`    | Mount path for the model cache                    | `/root/.ollama` |

### Probes

| Parameter        | Description     | Default                          |
| ---------------- | --------------- | -------------------------------- |
| `livenessProbe`  | Liveness probe  | HTTP GET `/` on `http`, 60s initial delay |
| `readinessProbe` | Readiness probe | HTTP GET `/` on `http`, 30s initial delay |

### Ingress

| Parameter             | Description         | Default  |
| --------------------- | ------------------- | -------- |
| `ingress.enabled`     | Enable Ingress      | `false`  |
| `ingress.className`   | Ingress class       | `cilium` |
| `ingress.annotations` | Ingress annotations | `{}`     |
| `ingress.hosts`       | Ingress hosts       | `[]`     |
| `ingress.tls`         | Ingress TLS         | `[]`     |

The chart does not expose a Gateway API `HTTPRoute` template - in most setups Ollama stays internal and Open WebUI handles user-facing traffic.

### Scheduling

| Parameter      | Description     | Default                            |
| -------------- | --------------- | ---------------------------------- |
| `nodeSelector` | Node selector   | `nvidia.com/gpu.present: "true"`   |
| `tolerations`  | Pod tolerations | `[]`                               |
| `affinity`     | Affinity rules  | `{}`                               |

## Examples

### GPU install with model preloading

```yaml
gpu:
  enabled: true
  runtimeClass: nvidia
  count: 1

models:
  - llama3:8b
  - mistral:7b
  - nomic-embed-text

resources:
  limits:
    cpu: "8"
    memory: "32Gi"
  requests:
    cpu: "2"
    memory: "8Gi"

persistence:
  enabled: true
  size: 200Gi
  storageClass: longhorn

nodeSelector:
  nvidia.com/gpu.present: "true"
```

### CPU-only install (small models only)

```yaml
gpu:
  enabled: false

models:
  - tinyllama:1.1b

resources:
  limits:
    cpu: "8"
    memory: "16Gi"
  requests:
    cpu: "2"
    memory: "4Gi"

persistence:
  enabled: true
  size: 20Gi

nodeSelector: {}
```

Expect single-digit tokens-per-second on CPU for 7B-class models. Use it for embeddings or `tinyllama`, not for chat.

### Large-model install (70B-class)

```yaml
gpu:
  enabled: true
  count: 2

models:
  - llama3:70b

resources:
  limits:
    cpu: "16"
    memory: "96Gi"
  requests:
    cpu: "4"
    memory: "32Gi"

persistence:
  enabled: true
  size: 500Gi
  storageClass: fast-ssd

env:
  - name: OLLAMA_NUM_PARALLEL
    value: "2"
  - name: OLLAMA_KEEP_ALIVE
    value: "24h"

nodeSelector:
  nvidia.com/gpu.present: "true"
```

Set `gpu.count` to match the number of GPUs Ollama should see; sharding a 70B model across two 24 GB GPUs requires `count: 2`.

## Persistence

`/root/.ollama` holds the manifest cache and every pulled model. This is the single biggest disk consumer in the chart - see the sizing table above. The chart creates one `ReadWriteOnce` PVC named `<release>-ollama-models`.

To preload models without baking them into a values file, exec into the pod and run `ollama pull <model>`. Anything you pull is durable across restarts.

## Integration notes

- **Open WebUI**: the [`open-webui`](https://github.com/geekxflood/helm-charts/tree/main/charts/open-webui) chart defaults `ollama.baseUrl` to `http://ollama:11434`, which matches this chart's Service name when installed as release `ollama` in the same namespace. Change either side if your release name differs.
- **OpenAI-compatible API**: anything that speaks the OpenAI Chat Completions schema can target `http://<release>.<namespace>:11434/v1` directly. Useful for LangChain, LiteLLM, Continue, etc.
- **GPU sharing**: Ollama loads one model at a time per GPU by default. Use `OLLAMA_MAX_LOADED_MODELS` to keep multiple models hot, mindful of VRAM.

## Upgrading

```bash
helm repo update
helm upgrade ollama geekxflood/ollama -f values.yaml
```

Resizing the PVC requires a storage class that supports volume expansion (`allowVolumeExpansion: true`) and an explicit edit of the PVC after the upgrade.

## Uninstallation

```bash
helm uninstall ollama
```

The PVC is retained by Helm. Delete it manually if you want to reclaim model storage.

## Support

- Upstream: <https://ollama.com/>
- Upstream issues: <https://github.com/ollama/ollama/issues>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. Ollama is distributed under the [MIT license](https://github.com/ollama/ollama/blob/main/LICENSE). Individual model weights are governed by their own licenses (Llama 3 community license, etc.) - review the model's licence before redistributing.

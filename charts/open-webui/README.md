# Open WebUI Helm Chart

![Version: 1.1.0](https://img.shields.io/badge/Version-1.1.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 0.4.8](https://img.shields.io/badge/AppVersion-0.4.8-informational?style=flat-square)

A Helm chart for deploying [Open WebUI](https://github.com/open-webui/open-webui) on Kubernetes. Open WebUI is a self-hosted chat interface for local LLMs - it talks to Ollama (or any OpenAI-compatible endpoint) and gives you ChatGPT-style conversations, document RAG, user accounts, and a model selector in a browser-friendly UI.

This chart deploys the official [ghcr.io/open-webui/open-webui](https://github.com/open-webui/open-webui/pkgs/container/open-webui) image. It is designed to be paired with the [`ollama`](https://github.com/geekxflood/helm-charts/tree/main/charts/ollama) chart, but works equally well against any external Ollama instance or OpenAI-compatible URL.

## Features

- Self-hosted ChatGPT-style web UI on port `8080`
- Configurable backend via `ollama.baseUrl` (in-cluster Ollama, external endpoint, or OpenAI-compatible service)
- Persistent storage for chat history, users, and uploaded documents
- Ingress, Gateway API `HTTPRoute`, and Cloudflare Tunnel exposure modes
- Reasonable resource defaults - Open WebUI runs comfortably on CPU
- Telemetry disabled by default (`DO_NOT_TRACK=true`, `ANONYMIZED_TELEMETRY=false`)

No GPU is required - the model inference runs in Ollama, this is the front-end.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- A reachable Ollama (or OpenAI-compatible) endpoint - this is what serves model responses
- PersistentVolume provisioner (persistence is enabled by default for chat data)
- For Gateway API: a Gateway controller and `HTTPRoute` CRDs
- For Cloudflare Tunnel: `cloudflare-operator` and a `Tunnel` / `ClusterTunnel` resource

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install open-webui geekxflood/open-webui
```

### Install with custom values

```bash
helm install open-webui geekxflood/open-webui -f values.yaml
```

## Configuration

### Core Parameters

| Parameter      | Description        | Default |
| -------------- | ------------------ | ------- |
| `replicaCount` | Number of replicas | `1`     |

Use a single replica unless you front it with sticky sessions and a shared backing store - Open WebUI keeps state in SQLite by default.

### Image

| Parameter          | Description       | Default                          |
| ------------------ | ----------------- | -------------------------------- |
| `image.repository` | Open WebUI image  | `ghcr.io/open-webui/open-webui` |
| `image.tag`        | Image tag         | `main`                           |
| `image.pullPolicy` | Image pull policy | `IfNotPresent`                   |

### Backend Connection

| Parameter         | Description                                          | Default                    |
| ----------------- | ---------------------------------------------------- | -------------------------- |
| `ollama.baseUrl`  | Ollama API URL (injected as `OLLAMA_BASE_URL` env)   | `http://ollama:11434`      |

The default assumes Ollama is installed as release `ollama` in the same namespace.

### Environment

| Parameter   | Description                                       | Default                                                                                                                            |
| ----------- | ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `env`       | Additional env vars (list of `{name, value}`)     | `WEBUI_AUTH=false`, `ENABLE_SIGNUP=true`, `DO_NOT_TRACK=true`, `ANONYMIZED_TELEMETRY=false`                                         |
| `envFrom`   | Env from `secret` / `configmap` references        | `[]`                                                                                                                               |

Useful env vars: `WEBUI_AUTH` (enable login), `ENABLE_SIGNUP`, `WEBUI_NAME`, `DEFAULT_MODELS`, `OPENAI_API_BASE_URL`, `OPENAI_API_KEY`. See the [Open WebUI env reference](https://docs.openwebui.com/getting-started/env-configuration/).

### Service Account & Pod

| Parameter                    | Description                | Default |
| ---------------------------- | -------------------------- | ------- |
| `serviceAccount.create`      | Create a ServiceAccount    | `true`  |
| `serviceAccount.name`        | Override SA name           | `""`    |
| `serviceAccount.annotations` | SA annotations             | `{}`    |
| `podAnnotations`             | Pod annotations            | `{}`    |
| `securityContext`            | Container security context | `{}`    |

### Service

| Parameter             | Description         | Default     |
| --------------------- | ------------------- | ----------- |
| `service.type`        | Service type        | `ClusterIP` |
| `service.port`        | Service port        | `8080`      |
| `service.annotations` | Service annotations | `{}`        |

### Ingress

| Parameter             | Description         | Default  |
| --------------------- | ------------------- | -------- |
| `ingress.enabled`     | Enable Ingress      | `false`  |
| `ingress.className`   | Ingress class       | `cilium` |
| `ingress.annotations` | Ingress annotations | `{}`     |
| `ingress.hosts`       | Ingress hosts       | `[]`     |
| `ingress.tls`         | Ingress TLS         | `[]`     |

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

| Parameter                | Description                                       | Default          |
| ------------------------ | ------------------------------------------------- | ---------------- |
| `cfTunnel.enabled`       | Create a `TunnelBinding`                          | `false`          |
| `cfTunnel.tunnelRef.name` | `Tunnel` / `ClusterTunnel` name                  | `""`             |
| `cfTunnel.tunnelRef.kind` | Reference kind                                   | `ClusterTunnel`  |
| `cfTunnel.subjects`      | Tunnel subjects (FQDN / protocol per Service)     | `[]`             |

### Persistence

| Parameter                  | Description                                       | Default                |
| -------------------------- | ------------------------------------------------- | ---------------------- |
| `persistence.enabled`      | Create a PVC mounted at `persistence.mountPath`   | `true`                 |
| `persistence.storageClass` | StorageClass                                      | `""`                   |
| `persistence.accessMode`   | Access mode                                       | `ReadWriteOnce`        |
| `persistence.size`         | PVC size                                          | `10Gi`                 |
| `persistence.mountPath`    | Mount path                                        | `/app/backend/data`    |

`/app/backend/data` holds the SQLite database (users, chats), uploaded documents, vector store, and configuration. Lose this and you lose history.

### Resources & Probes

| Parameter        | Description     | Default                                                                          |
| ---------------- | --------------- | -------------------------------------------------------------------------------- |
| `resources`      | Resource specs  | `limits: cpu=2, memory=2Gi`; `requests: cpu=500m, memory=512Mi`                  |
| `livenessProbe`  | Liveness probe  | HTTP GET `/health` on `http`, 30s initial delay                                  |
| `readinessProbe` | Readiness probe | HTTP GET `/health/ready` on `http`, 15s initial delay                            |

### Scheduling

| Parameter      | Description     | Default |
| -------------- | --------------- | ------- |
| `nodeSelector` | Node selector   | `{}`    |
| `tolerations`  | Pod tolerations | `[]`    |
| `affinity`     | Affinity rules  | `{}`    |

## Examples

### Standard install pointed at in-cluster Ollama

```yaml
ollama:
  baseUrl: "http://ollama:11434"

env:
  - name: WEBUI_AUTH
    value: "true"
  - name: ENABLE_SIGNUP
    value: "false"
  - name: WEBUI_NAME
    value: "Home LLM"
  - name: DO_NOT_TRACK
    value: "true"

persistence:
  enabled: true
  size: 20Gi
  storageClass: longhorn

ingress:
  enabled: true
  className: cilium
  hosts:
    - host: chat.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: chat-tls
      hosts:
        - chat.example.com
```

### Gateway API HTTPRoute

```yaml
ollama:
  baseUrl: "http://ollama:11434"

ingress:
  enabled: false

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - chat.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1
```

Cilium operators: `parentRefs[*].port` is ignored - use `sectionName`. Cross-namespace `backendRefs` need a `ReferenceGrant`.

### Cloudflare Tunnel exposure

```yaml
ollama:
  baseUrl: "http://ollama:11434"

ingress:
  enabled: false

cfTunnel:
  enabled: true
  tunnelRef:
    name: home-cluster
    kind: ClusterTunnel
  subjects:
    - name: open-webui
      spec:
        fqdn: chat.example.com
        protocol: http
```

### Pointed at a remote Ollama or OpenAI-compatible endpoint

```yaml
ollama:
  baseUrl: "http://ollama.remote.lan:11434"

envFrom:
  - secretRef:
      name: openwebui-secrets

env:
  - name: OPENAI_API_BASE_URL
    value: "https://api.openai.com/v1"
```

Provision a Secret named `openwebui-secrets` with `OPENAI_API_KEY` to enable OpenAI as a secondary provider.

## Persistence

Open WebUI stores its entire state under `/app/backend/data`:

- `webui.db` - SQLite with users, sessions, chats, models
- `vector_db/` - embeddings for the built-in RAG
- `uploads/` - uploaded documents
- `cache/` - thumbnails, transient data

Plan storage accordingly if you enable document RAG with many uploads. 10 GiB is enough for typical chat-only use; bump to 50-100 GiB for heavy document ingestion.

## Integration notes

- **Ollama wiring**: the default `ollama.baseUrl=http://ollama:11434` resolves to the `ollama` Service in the same namespace. If you renamed the release, set `ollama.baseUrl=http://<release-name>:11434`. For cross-namespace, use the FQDN: `http://ollama.media.svc.cluster.local:11434`.
- **Authentication**: defaults set `WEBUI_AUTH=false` and `ENABLE_SIGNUP=true` for first-run convenience. Lock both down before exposing publicly.
- **HTTPS behind a proxy**: Open WebUI honors `X-Forwarded-*` headers. Make sure your Ingress / Gateway forwards them so OAuth and absolute URLs work.
- **OpenAI compatibility**: any OpenAI-compatible endpoint works through `OPENAI_API_BASE_URL` and `OPENAI_API_KEY` - useful for LiteLLM, vLLM, or Anthropic-compatible proxies.

## Upgrading

```bash
helm repo update
helm upgrade open-webui geekxflood/open-webui -f values.yaml
```

Open WebUI runs schema migrations against the SQLite database at startup - keep the PVC across upgrades. Probes can take up to ~30s after a migration; the defaults are generous enough.

## Uninstallation

```bash
helm uninstall open-webui
```

The data PVC is retained by Helm. Delete it manually if you want to reclaim storage.

## Support

- Upstream: <https://github.com/open-webui/open-webui>
- Upstream docs: <https://docs.openwebui.com/>
- Upstream issues: <https://github.com/open-webui/open-webui/issues>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. Open WebUI is distributed under the [MIT license](https://github.com/open-webui/open-webui/blob/main/LICENSE).

# Lingarr Helm Chart

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

[Lingarr](https://github.com/lingarr-translate/lingarr) is an automatic subtitle **translator** that hooks into Bazarr (and optionally Radarr/Sonarr) and uses an LLM provider — OpenAI, Anthropic, DeepL, LibreTranslate, Ollama, or any OpenAI-compatible endpoint — to translate existing subtitles into the languages you actually speak. This chart runs Lingarr on Kubernetes using the official [`lingarr/lingarr`](https://hub.docker.com/r/lingarr/lingarr) image and exposes it via Ingress or Gateway API HTTPRoute.

Lingarr is **not** a subtitle downloader. It translates subtitles that already exist (typically the ones Bazarr fetched). Use Bazarr for sourcing, Lingarr for translation.

## Features

- `Deployment` with `Recreate` strategy by default — `ReadWriteOnce` config volume holds the SQLite DB and per-job state.
- Optional static-binding `PersistentVolumeClaim` for `/app/config` (5 GiB default — Lingarr's footprint is small).
- `ClusterIP` service on port `8080`.
- Two exposure modes: classic `Ingress` and Gateway API `HTTPRoute` (`gateway.networking.k8s.io/v1`).
- HTTP probes on `/` with timings tuned for occasional LLM-call backpressure (period 30 s liveness, 15 s readiness, 10 s timeout).
- HPA scaffolding included — but Lingarr maintains job state in SQLite, so leave `replicaCount: 1`.

This chart does **not** ship a Cloudflare Tunnel `TunnelBinding` or OpenBao API-key sync. Lingarr exposes no API key of its own; provider credentials (OpenAI, etc.) are configured inside Lingarr's UI and stored in `/app/config`.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.0+
- A `StorageClass` supporting `ReadWriteOnce` for `/app/config`.
- Either:
  - A running Bazarr instance (recommended path), **and** access to the same media volumes that Bazarr/Radarr/Sonarr mount; **or**
  - Direct access to `/movies` and `/tv` PVCs where Lingarr can read existing `.srt` files.
- A translation backend reachable from the pod:
  - **Hosted**: an OpenAI / Anthropic / DeepL / OpenRouter API key.
  - **Self-hosted**: an Ollama or LibreTranslate service in-cluster.
- Optional: [Gateway API CRDs](https://gateway-api.sigs.k8s.io/) for `httpRoute`.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install

```bash
helm install lingarr geekxflood/lingarr
helm install lingarr geekxflood/lingarr -f values.yaml
```

Lingarr ships with `enabled: false`. Set `enabled: true` to render workloads.

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

| Parameter          | Description                                  | Default           |
| ------------------ | -------------------------------------------- | ----------------- |
| `image.repository` | Container image                              | `lingarr/lingarr` |
| `image.tag`        | Image tag (falls back to `Chart.appVersion`) | `"latest"`        |
| `image.pullPolicy` | Image pull policy                            | `Always`          |
| `imagePullSecrets` | Pull secrets list                            | `[]`              |

### Pod & Service Account

| Parameter                    | Description                | Default |
| ---------------------------- | -------------------------- | ------- |
| `serviceAccount.create`      | Create a dedicated SA      | `true`  |
| `serviceAccount.automount`   | Auto-mount SA token        | `true`  |
| `serviceAccount.annotations` | SA annotations             | `{}`    |
| `serviceAccount.name`        | Override SA name           | `""`    |
| `podAnnotations`             | Pod annotations            | `{}`    |
| `podLabels`                  | Pod labels                 | `{}`    |
| `podSecurityContext`         | Pod-level security context | `{}`    |
| `securityContext`            | Container security context | `{}`    |
| `env`                        | Container env vars         | `[]`    |

Lingarr accepts runtime tuning via `env` — see the upstream docs for variables like `MAX_CONCURRENT_JOBS`, `DB_CONNECTION`, and provider toggles.

### Service

| Parameter      | Description              | Default     |
| -------------- | ------------------------ | ----------- |
| `service.type` | Kubernetes service type  | `ClusterIP` |
| `service.port` | Service & container port | `8080`      |

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

Omitting `backendRefs[*].name`/`port` defaults to this chart's service on `service.port`.

### Persistence (`/app/config`)

| Parameter                  | Description                                        | Default                |
| -------------------------- | -------------------------------------------------- | ---------------------- |
| `persistence.enabled`      | Render the config PVC                              | `false`                |
| `persistence.name`         | PVC name override (default `<release>-config-pvc`) | `""`                   |
| `persistence.storageClass` | Storage class                                      | `""` (cluster default) |
| `persistence.accessMode`   | PVC access mode                                    | `ReadWriteOnce`        |
| `persistence.size`         | Requested storage                                  | `5Gi`                  |
| `persistence.volumeName`   | Bind to a specific `PersistentVolume`              | `""`                   |

### Volumes / Volume Mounts

| Parameter      | Description                         | Default |
| -------------- | ----------------------------------- | ------- |
| `volumes`      | Additional `pod.spec.volumes`       | `[]`    |
| `volumeMounts` | Additional `container.volumeMounts` | `[]`    |

### Probes

| Parameter        | Description                         | Default                                     |
| ---------------- | ----------------------------------- | ------------------------------------------- |
| `livenessProbe`  | Liveness probe (HTTP GET `/`:8080)  | `initialDelay 60s, period 30s, timeout 10s` |
| `readinessProbe` | Readiness probe (HTTP GET `/`:8080) | `initialDelay 30s, period 15s, timeout 10s` |

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

## Examples

### Basic install with Ingress, integrated with Bazarr

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: MAX_CONCURRENT_JOBS
    value: "1"
  - name: DB_CONNECTION
    value: "sqlite"

persistence:
  enabled: true
  size: 2Gi
  storageClass: longhorn

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: lingarr-config-pvc
  - name: movies
    persistentVolumeClaim:
      claimName: media-movies     # same PVC Radarr/Bazarr mount
  - name: tv
    persistentVolumeClaim:
      claimName: media-tv         # same PVC Sonarr/Bazarr mount

volumeMounts:
  - name: config
    mountPath: /app/config
  - name: movies
    mountPath: /movies
  - name: tv
    mountPath: /tv

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: lingarr.example.com
      paths:
        - path: /
          pathType: Prefix
```

After install, open Lingarr and add:

- **Bazarr connection**: `http://bazarr.media.svc.cluster.local:6767` with the Bazarr API key.
- **Radarr / Sonarr connections** (optional, for richer metadata): the same URLs you use elsewhere.
- **Translation backend**: pick OpenAI/Anthropic/Ollama in `Settings → Services` and paste your provider key.

### HTTPRoute + self-hosted Ollama backend

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  # Lingarr's UI is where you point at Ollama, but you can pre-seed env defaults the app respects.
  - name: MAX_CONCURRENT_JOBS
    value: "2"

persistence:
  enabled: true
  size: 2Gi

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: lingarr-config-pvc
  - name: movies
    persistentVolumeClaim:
      claimName: media-movies
  - name: tv
    persistentVolumeClaim:
      claimName: media-tv

volumeMounts:
  - name: config
    mountPath: /app/config
  - name: movies
    mountPath: /movies
  - name: tv
    mountPath: /tv

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - lingarr.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1
```

In Lingarr's UI, configure `Services → Ollama` with the in-cluster URL of your Ollama deployment (e.g. `http://ollama.ai.svc.cluster.local:11434`) and a model that handles translation well (`qwen2.5`, `llama3.1`, etc.).

CLI equivalent for a minimal install:

```bash
helm install lingarr geekxflood/lingarr \
  --set enabled=true \
  --set persistence.enabled=true \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set 'ingress.hosts[0].host=lingarr.example.com' \
  --set 'ingress.hosts[0].paths[0].path=/' \
  --set 'ingress.hosts[0].paths[0].pathType=Prefix'
```

## Persistence

| Mount         | Purpose                                                        | Provided by chart?          |
| ------------- | -------------------------------------------------------------- | --------------------------- |
| `/app/config` | SQLite DB, job state, provider settings                        | Yes, via `persistence.*`    |
| `/movies`     | Read access to existing subtitles; write for translated `.srt` | No, share Radarr/Bazarr PVC |
| `/tv`         | Read access to existing subtitles; write for translated `.srt` | No, share Sonarr/Bazarr PVC |

Lingarr writes its translated subtitle files next to the source video (e.g. `Movie.fr.srt` beside `Movie.en.srt`). Mount the same library PVCs that Bazarr uses, with the same paths, so all three tools see a consistent tree.

## Integration notes

- **Bazarr → Lingarr**: configure Lingarr's `Services → Bazarr` with the in-cluster service URL and the Bazarr API key. Lingarr polls Bazarr for new subtitles to translate.
- **Radarr / Sonarr → Lingarr**: optional, only needed if you want Lingarr to pull richer metadata (genres, series episode IDs) than Bazarr exposes. Same URL/API-key pattern as the other charts.
- **Translation providers**: configured in the UI, not in `values.yaml`. Credentials persist in `/app/config`, so back up that volume.
- **No Prowlarr integration** — translation has nothing to do with indexers.

## Upgrading

`persistence.volumeName` enables static PV binding. Set it to the previously-bound PV before upgrade to avoid losing provider credentials and job history.

## Support

- Upstream: <https://github.com/lingarr-translate/lingarr>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. Lingarr is licensed under the [AGPL-3.0](https://github.com/lingarr-translate/lingarr/blob/main/LICENSE).

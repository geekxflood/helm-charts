# Program Director Helm Chart

![Version: 1.2.0](https://img.shields.io/badge/Version-1.2.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.1.1](https://img.shields.io/badge/AppVersion-1.1.1-informational?style=flat-square)

[Program Director](https://github.com/geekxflood/program-director) is an AI-driven scheduler for [Tunarr](https://tunarr.com/). It pulls library inventory from Radarr/Sonarr, talks to a local [Ollama](https://ollama.com/) model to pick what should air tonight on a themed channel ("80s sci-fi night", "Saturday morning anime"), respects per-media cooldowns so the same movie isn't programmed twice in a row, and writes the resulting playlist back to a Tunarr channel. Deploy this when your home-grown TV station has outgrown manually dragging episodes onto a timeline.

## Features

- HTTP `Ingress` and Gateway API `HTTPRoute` exposure
- Built-in Prometheus metrics endpoint (`/metrics`) with optional `ServiceMonitor`
- SQLite (default) or PostgreSQL backend — driver swap is values-only
- Generated `ConfigMap` for `config.yaml`, generated `Secret` for Radarr/Sonarr/Trakt API keys (or bring `existingSecret`)
- Read-only root filesystem and non-root pod security context out of the box
- Built-in cron scheduler (`--enable-scheduler`) that fires per-theme on a values-defined cron expression
- Pluggable `initContainers`, `extraContainers`, `extraVolumes`, `extraVolumeMounts` for unusual deployments
- `/health` and `/ready` HTTP probes — readiness flips false if the DB is unreachable
- ConfigMap checksum annotation on the deployment — pods restart on config change

## Prerequisites

- Kubernetes 1.19+ (Gateway API CRDs `gateway.networking.k8s.io/v1` if `httpRoute.enabled=true`)
- Helm 3.2+
- A PV provisioner if `persistence.enabled=true` (default; required for SQLite)
- Reachable Radarr, Sonarr, and Tunarr instances inside the cluster
- A reachable [Ollama](https://ollama.com/) server with a chat-capable model pulled (default `dolphin-llama3:8b`)
- Optional: a PostgreSQL instance if you set `config.database.driver=postgres`
- Optional: Prometheus Operator if `metrics.serviceMonitor.enabled=true`
- Optional: a Trakt.tv application (client id + secret) for richer recommendations

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install with default values

```bash
helm install program-director geekxflood/program-director \
  --set config.radarr.apiKey=$RADARR_KEY \
  --set config.sonarr.apiKey=$SONARR_KEY
```

### Install with custom values

```bash
helm install program-director geekxflood/program-director -f values.yaml
```

## Configuration

### Image & Replicas

| Parameter          | Description                              | Default                                |
| ------------------ | ---------------------------------------- | -------------------------------------- |
| `image.repository` | Image repository                         | `ghcr.io/geekxflood/program-director`  |
| `image.tag`        | Image tag (defaults to Chart appVersion) | `""`                                   |
| `image.pullPolicy` | Image pull policy                        | `IfNotPresent`                         |
| `replicaCount`     | Replica count                            | `1`                                    |

### Service

| Parameter             | Description         | Default     |
| --------------------- | ------------------- | ----------- |
| `service.type`        | Service type        | `ClusterIP` |
| `service.port`        | Service port        | `8080`      |
| `service.annotations` | Service annotations | `{}`        |

### Ingress

| Parameter             | Description         | Default                  |
| --------------------- | ------------------- | ------------------------ |
| `ingress.enabled`     | Enable Ingress      | `false`                  |
| `ingress.className`   | IngressClass name   | `""`                     |
| `ingress.annotations` | Ingress annotations | `{}`                     |
| `ingress.hosts`       | Host rules          | `[{host: program-director.local, ...}]` |
| `ingress.tls`         | TLS configuration   | `[]`                     |

### HTTPRoute (Gateway API)

| Parameter               | Description                                            | Default |
| ----------------------- | ------------------------------------------------------ | ------- |
| `httpRoute.enabled`     | Enable Gateway API HTTPRoute                           | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                                  | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                                       | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments (required when enabled) | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                            | `[]`    |
| `httpRoute.rules`       | Route rules (matches + backendRefs)                    | `[]`    |

Omitted `backendRefs[*].name`/`port` target this chart's service on `service.port` (8080).

### Application Config

| Parameter                       | Description                                         | Default                     |
| ------------------------------- | --------------------------------------------------- | --------------------------- |
| `config.debug`                  | `--debug` flag                                      | `false`                     |
| `config.jsonLogs`               | `--json` flag (structured logs)                     | `false`                     |
| `config.server.port`            | HTTP listen port                                    | `8080`                      |
| `config.server.enableScheduler` | Enable the built-in cron scheduler                  | `false`                     |
| `config.server.metricsEnabled`  | Expose `/metrics`                                   | `true`                      |
| `config.server.shutdownTimeout` | Graceful shutdown timeout (seconds)                 | `30`                        |
| `config.cooldown.movieDays`     | Days a movie can't be re-programmed                 | `30`                        |
| `config.cooldown.seriesDays`    | Days a series episode can't repeat                  | `14`                        |
| `config.cooldown.animeDays`     | Days an anime episode can't repeat                  | `14`                        |

### Database

| Parameter                           | Description                                  | Default                       |
| ----------------------------------- | -------------------------------------------- | ----------------------------- |
| `config.database.driver`            | `sqlite` or `postgres`                       | `sqlite`                      |
| `config.database.sqlite.path`       | SQLite path (PVC-backed)                     | `/data/program-director.db`   |
| `config.database.postgres.host`     | PostgreSQL host                              | `postgresql`                  |
| `config.database.postgres.port`     | PostgreSQL port                              | `5432`                        |
| `config.database.postgres.database` | Database name                                | `program_director`            |
| `config.database.postgres.user`     | User                                         | `program_director`            |
| `config.database.postgres.password` | Password (stored in generated Secret)        | `""`                          |
| `config.database.postgres.sslmode`  | sslmode                                      | `disable`                     |

### External Integrations

| Parameter                   | Description                          | Default               |
| --------------------------- | ------------------------------------ | --------------------- |
| `config.radarr.url`         | Radarr URL                           | `http://radarr:7878`  |
| `config.radarr.apiKey`      | Radarr API key (Secret-injected)     | `""`                  |
| `config.sonarr.url`         | Sonarr URL                           | `http://sonarr:8989`  |
| `config.sonarr.apiKey`      | Sonarr API key (Secret-injected)     | `""`                  |
| `config.tunarr.url`         | Tunarr URL                           | `http://tunarr:8000`  |
| `config.trakt.clientId`     | Trakt client id (optional)           | `""`                  |
| `config.trakt.clientSecret` | Trakt client secret (optional)       | `""`                  |
| `config.ollama.url`         | Ollama URL                           | `http://ollama:11434` |
| `config.ollama.model`       | Ollama model name                    | `dolphin-llama3:8b`   |
| `config.ollama.temperature` | LLM temperature                      | `0.7`                 |
| `config.ollama.numCtx`      | LLM context window (tokens)          | `8192`                |

Secrets management: by default the chart renders a `Secret` named `<release>-program-director-config` containing `radarr-api-key`, `sonarr-api-key`, and (when set) `trakt-client-id`, `trakt-client-secret`, `postgres-password`. To bring your own, set `existingSecret` to the name of a pre-existing Secret with those same keys.

### Themes (the scheduler input)

`config.themes` is a list. Each item describes a programming block the LLM will fill.

```yaml
config:
  themes:
    - name: sci-fi-night            # required, used as the theme id
      description: "Science fiction movies and shows"
      channelId: "channel-1"        # Tunarr channel id to write to
      schedule: "0 20 * * *"        # cron, only used when scheduler is enabled
      mediaTypes: ["movie", "series"]
      genres: ["Science Fiction", "Sci-Fi"]
      keywords: ["space", "future"]
      minRating: 7.0
      maxItems: 20
      duration: 180                 # minutes
```

### Persistence

| Parameter                  | Description        | Default         |
| -------------------------- | ------------------ | --------------- |
| `persistence.enabled`      | Create a data PVC  | `true`          |
| `persistence.storageClass` | Storage class      | `""`            |
| `persistence.accessMode`   | Access mode        | `ReadWriteOnce` |
| `persistence.size`         | PVC size           | `10Gi`          |
| `persistence.annotations`  | PVC annotations    | `{}`            |

### Metrics

| Parameter                            | Description                       | Default |
| ------------------------------------ | --------------------------------- | ------- |
| `metrics.enabled`                    | Master switch for metrics objects | `true`  |
| `metrics.serviceMonitor.enabled`     | Render a ServiceMonitor           | `false` |
| `metrics.serviceMonitor.interval`    | Scrape interval                   | `30s`   |
| `metrics.serviceMonitor.scrapeTimeout` | Scrape timeout                  | `10s`   |
| `metrics.serviceMonitor.labels`      | Additional labels                 | `{}`    |

Exposed series include `program_director_media_total`, `program_director_history_plays_total`, `program_director_cooldowns_active`, and `program_director_themes_configured`.

### Resources, Probes, Extensibility

| Parameter             | Description                                 | Default         |
| --------------------- | ------------------------------------------- | --------------- |
| `resources.requests`  | CPU/memory requests                         | `100m` / `256Mi`|
| `resources.limits`    | CPU/memory limits                           | `1000m` / `1Gi` |
| `livenessProbe`       | HTTP `GET /health`                          | see `values.yaml` |
| `readinessProbe`      | HTTP `GET /ready` (checks DB)               | see `values.yaml` |
| `initContainers`      | Extra init containers (list)                | `[]`            |
| `extraContainers`     | Extra sidecars (list)                       | `[]`            |
| `extraVolumes`        | Extra pod volumes                           | `[]`            |
| `extraVolumeMounts`   | Extra container volume mounts               | `[]`            |
| `env`                 | Additional env entries (Secret refs etc.)   | `[]`            |
| `existingSecret`      | Pre-existing Secret name (skips generation) | `""`            |

## Examples

### Single-replica with SQLite, Ingress, and one theme

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: program-director.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: program-director-tls
      hosts:
        - program-director.example.com

config:
  radarr:
    url: http://radarr.media.svc:7878
    apiKey: "REDACTED"
  sonarr:
    url: http://sonarr.media.svc:8989
    apiKey: "REDACTED"
  tunarr:
    url: http://tunarr.media.svc:8000
  ollama:
    url: http://ollama.ai.svc:11434
    model: dolphin-llama3:8b
  server:
    enableScheduler: true
  themes:
    - name: sci-fi-night
      description: "Science fiction evening"
      channelId: "channel-1"
      schedule: "0 20 * * *"
      genres: ["Science Fiction", "Sci-Fi"]
      keywords: ["space", "future"]
      minRating: 7.0
      maxItems: 20
      duration: 180

persistence:
  enabled: true
  size: 10Gi
```

### Postgres backend, existing Secret, HTTPRoute, ServiceMonitor

For production where you'd rather not commit API keys to values, run on Postgres, and have Prometheus Operator scrape metrics:

```yaml
replicaCount: 2

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - program-director.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1

config:
  jsonLogs: true
  database:
    driver: postgres
    postgres:
      host: postgres-cluster-rw.databases.svc
      port: 5432
      database: program_director
      user: program_director
      # password lives in the existing Secret as `postgres-password`
      sslmode: require
  radarr:
    url: http://radarr.media.svc:7878
  sonarr:
    url: http://sonarr.media.svc:8989
  tunarr:
    url: http://tunarr.media.svc:8000
  ollama:
    url: http://ollama.ai.svc:11434
    model: dolphin-llama3:8b
  server:
    enableScheduler: true
    metricsEnabled: true

existingSecret: program-director-secrets

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    labels:
      release: kube-prometheus-stack

persistence:
  enabled: true
  storageClass: fast-ssd
  size: 20Gi
```

Create the matching Secret out-of-band:

```bash
kubectl create secret generic program-director-secrets \
  --from-literal=radarr-api-key='REDACTED' \
  --from-literal=sonarr-api-key='REDACTED' \
  --from-literal=postgres-password='REDACTED'
```

Cilium operators: `parentRefs[*].port` is ignored — target a listener via `sectionName`. Cross-namespace `backendRefs` require a `ReferenceGrant`.

## Persistence

When `config.database.driver=sqlite` (the default), the chart mounts a PVC at `/data` and the database lives at `config.database.sqlite.path` (default `/data/program-director.db`). The container also gets a writable `emptyDir` at `/tmp` because the pod runs with `readOnlyRootFilesystem: true`.

When the driver is `postgres`, the data PVC is unnecessary — set `persistence.enabled=false` to skip it.

## Upgrading

Schema migrations run on startup. The deployment carries a `checksum/config` annotation on its pod template, so any change to `config.*` triggers a rolling restart. Two safe upgrade habits:

1. Snapshot the DB before bumping the image tag.

   ```bash
   # SQLite
   kubectl exec deploy/program-director -- sqlite3 /data/program-director.db ".backup '/tmp/pd-$(date +%F).db'"
   # Postgres
   kubectl exec deploy/postgres-0 -- pg_dump -U program_director program_director > pd-$(date +%F).sql
   ```

2. Re-render values with `helm template` to confirm the generated `ConfigMap` matches what the new image expects.

## Support

- Upstream project: <https://github.com/geekxflood/program-director>
- Tunarr: <https://tunarr.com/> · Radarr: <https://radarr.video/> · Sonarr: <https://sonarr.tv/> · Ollama: <https://ollama.com/>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. Program Director is an open-source project maintained by [geekxflood](https://github.com/geekxflood/program-director).

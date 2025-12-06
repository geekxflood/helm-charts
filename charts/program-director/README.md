# Program Director Helm Chart

This Helm chart deploys Program Director on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (for SQLite persistence)

## Installing the Chart

```bash
helm install program-director ./charts/program-director
```

## Uninstalling the Chart

```bash
helm uninstall program-director
```

## Configuration

The following table lists the configurable parameters and their default values.

### Image Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image repository | `ghcr.io/geekxflood/program-director` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.tag` | Image tag (defaults to Chart appVersion) | `""` |

### Deployment Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `256Mi` |
| `resources.limits.cpu` | CPU limit | `1000m` |
| `resources.limits.memory` | Memory limit | `1Gi` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8080` |

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.hosts[0].host` | Hostname | `program-director.local` |

### Database Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.database.driver` | Database driver (sqlite or postgres) | `sqlite` |
| `config.database.sqlite.path` | SQLite database path | `/data/program-director.db` |
| `config.database.postgres.host` | PostgreSQL host | `postgresql` |
| `config.database.postgres.port` | PostgreSQL port | `5432` |
| `config.database.postgres.database` | PostgreSQL database name | `program_director` |
| `config.database.postgres.user` | PostgreSQL user | `program_director` |
| `config.database.postgres.password` | PostgreSQL password | `""` |

### API Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.radarr.url` | Radarr URL | `http://radarr:7878` |
| `config.radarr.apiKey` | Radarr API key | `""` |
| `config.sonarr.url` | Sonarr URL | `http://sonarr:8989` |
| `config.sonarr.apiKey` | Sonarr API key | `""` |
| `config.tunarr.url` | Tunarr URL | `http://tunarr:8000` |
| `config.trakt.clientId` | Trakt.tv client ID (optional) | `""` |
| `config.trakt.clientSecret` | Trakt.tv client secret (optional) | `""` |

### Ollama Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.ollama.url` | Ollama URL | `http://ollama:11434` |
| `config.ollama.model` | Ollama model | `dolphin-llama3:8b` |
| `config.ollama.temperature` | Temperature | `0.7` |
| `config.ollama.numCtx` | Context window size | `8192` |

### Server Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.server.port` | HTTP server port | `8080` |
| `config.server.enableScheduler` | Enable cron scheduler | `false` |
| `config.server.metricsEnabled` | Enable Prometheus metrics | `true` |

### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable persistence | `true` |
| `persistence.storageClass` | Storage class | `""` |
| `persistence.accessMode` | Access mode | `ReadWriteOnce` |
| `persistence.size` | Volume size | `10Gi` |

## Example Values

### Minimal Configuration

```yaml
config:
  radarr:
    url: http://radarr.media.svc:7878
    apiKey: "your-radarr-api-key"
  sonarr:
    url: http://sonarr.media.svc:8989
    apiKey: "your-sonarr-api-key"
  tunarr:
    url: http://tunarr.media.svc:8000
  themes:
    - name: sci-fi-night
      description: "Science fiction movies and shows"
      channelId: "channel-1"
      genres: ["Science Fiction"]
      minRating: 7.0
      duration: 180
```

### Production Configuration

```yaml
replicaCount: 2

resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi

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
  debug: false
  jsonLogs: true

  database:
    driver: postgres
    postgres:
      host: postgresql.database.svc
      port: 5432
      database: program_director
      user: program_director
      password: "secure-password"

  server:
    enableScheduler: true
    metricsEnabled: true

  themes:
    - name: sci-fi-night
      description: "Science fiction evening"
      channelId: "channel-1"
      schedule: "0 20 * * *"
      genres: ["Science Fiction", "Sci-Fi"]
      keywords: ["space", "future", "technology"]
      minRating: 7.0
      maxItems: 20
      duration: 180

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s

persistence:
  enabled: true
  storageClass: fast-ssd
  size: 20Gi
```

### With External Secret

```yaml
existingSecret: program-director-secrets

config:
  radarr:
    url: http://radarr.media.svc:7878
  sonarr:
    url: http://sonarr.media.svc:8989
```

Create the secret separately:

```bash
kubectl create secret generic program-director-secrets \
  --from-literal=radarr-api-key='your-radarr-key' \
  --from-literal=sonarr-api-key='your-sonarr-key'
```

## Monitoring

The chart includes Prometheus metrics support:

1. Enable metrics in values:
```yaml
config:
  server:
    metricsEnabled: true
```

2. (Optional) Enable ServiceMonitor for Prometheus Operator:
```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

Metrics available at `/metrics` endpoint:
- `program_director_media_total` - Total media items by type
- `program_director_history_plays_total` - Total plays recorded
- `program_director_cooldowns_active` - Active cooldowns
- `program_director_themes_configured` - Configured themes

## Scheduler

Enable automated playlist generation:

```yaml
config:
  server:
    enableScheduler: true
```

Configure schedules per theme:

```yaml
config:
  themes:
    - name: morning-show
      schedule: "0 6 * * *"  # Daily at 6 AM
      ...
    - name: prime-time
      schedule: "0 20 * * *"  # Daily at 8 PM
      ...
```

## Health Checks

The chart includes health checks:

- **Liveness probe**: `/health` - Checks if application is running
- **Readiness probe**: `/ready` - Checks database connectivity

Customize probe settings:

```yaml
livenessProbe:
  initialDelaySeconds: 30
  periodSeconds: 30

readinessProbe:
  initialDelaySeconds: 10
  periodSeconds: 10
```

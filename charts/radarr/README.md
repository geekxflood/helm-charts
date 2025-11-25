# Radarr Helm Chart

![Version: 0.3.0](https://img.shields.io/badge/Version-0.3.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 5.17.2](https://img.shields.io/badge/AppVersion-5.17.2-informational?style=flat-square)

A Helm chart for deploying Radarr on Kubernetes.

## Overview

[Radarr](https://radarr.video/) is a movie collection manager for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new movies and will interface with clients and indexers to grab, sort, and rename them. It can also be configured to automatically upgrade the quality of existing files in the library when a better quality format becomes available.

This Helm chart deploys Radarr on a Kubernetes cluster using the [LinuxServer.io Radarr image](https://hub.docker.com/r/linuxserver/radarr).

## Features

- Automatic movie downloading and management
- Quality profile management
- Calendar integration
- Integration with download clients (SABnzbd, NZBGet, Transmission, etc.)
- OpenBao API key synchronization (optional)
- Health checks with liveness and readiness probes
- Cloudflare Tunnel support

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Persistent storage for configuration and media files
- Download client (Transmission, SABnzbd, etc.)
- Indexer (Prowlarr recommended)

## Installation

### Add the Helm repository

```bash
helm repo add your-repo https://your-repo-url
helm repo update
```

### Install the chart

```bash
helm install radarr your-repo/radarr
```

### Install with custom values

```bash
helm install radarr your-repo/radarr -f values.yaml
```

## Configuration

The following table lists the configurable parameters of the Radarr chart and their default values.

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `enabled` | Enable/disable the chart deployment | `false` |
| `replicaCount` | Number of Radarr replicas | `1` |

### Image Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Radarr image repository | `linuxserver/radarr` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `image.tag` | Image tag | `"5.17.2"` |
| `imagePullSecrets` | Image pull secrets | `[]` |

### Service Account Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create service account | `true` |
| `serviceAccount.automount` | Automount service account token | `true` |
| `serviceAccount.annotations` | Service account annotations | `{}` |
| `serviceAccount.name` | Service account name | `""` |

### Pod Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full chart name | `""` |
| `podAnnotations` | Pod annotations | `{}` |
| `podLabels` | Pod labels | `{}` |
| `podSecurityContext` | Pod security context | `{}` |
| `securityContext` | Container security context | `{}` |

### Environment Variables

| Parameter | Description | Default |
|-----------|-------------|---------|
| `env` | Environment variables array | See values.yaml |
| `env[].PUID` | User ID for file permissions | `1000` |
| `env[].PGID` | Group ID for file permissions | `100` |
| `env[].TZ` | Timezone | `Europe/Zurich` |

### Service Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `7878` |

### Ingress Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class name | `cilium` |
| `ingress.annotations` | Ingress annotations | See values.yaml |
| `ingress.hosts` | Ingress hosts configuration | See values.yaml |
| `ingress.tls` | Ingress TLS configuration | See values.yaml |

### Cloudflare Tunnel Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cfTunnel.enabled` | Enable Cloudflare Tunnel | `false` |
| `cfTunnel.tunnelRef` | Tunnel reference | `{}` |
| `cfTunnel.subjects` | Tunnel subjects | `[]` |

### Health Check Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `livenessProbe.httpGet.path` | Liveness probe HTTP path | `/` |
| `livenessProbe.initialDelaySeconds` | Initial delay for liveness probe | `60` |
| `livenessProbe.periodSeconds` | Period for liveness probe | `60` |
| `readinessProbe.httpGet.path` | Readiness probe HTTP path | `/` |
| `readinessProbe.initialDelaySeconds` | Initial delay for readiness probe | `30` |
| `readinessProbe.periodSeconds` | Period for readiness probe | `30` |

### OpenBao Integration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `openbao.enabled` | Enable API key sync to OpenBao | `false` |
| `openbao.address` | OpenBao cluster address | `http://openbao.openbao.svc.cluster.local:8200` |
| `openbao.authMount` | Kubernetes auth mount path | `kubernetes` |
| `openbao.role` | OpenBao role for authentication | `radarr` |
| `openbao.kvPath` | KV path for API key storage | `secret/arr/radarr` |
| `openbao.serviceUrl` | Service URL for external applications | See values.yaml |

### Resource Management

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources` | Resource requests and limits | `{}` |

### Autoscaling Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable horizontal pod autoscaler | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `100` |

### Storage Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `volumes` | Volume definitions | See values.yaml |
| `volumeMounts` | Volume mount definitions | See values.yaml |

### Node Selection Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |

## Storage Requirements

Radarr requires persistent storage for:

1. **Configuration** (`/config`): Application configuration, database, and metadata
2. **Movies** (`/data/movie`): Movie library directory
3. **Downloads** (`/data/downloads`): Download client directory

### Default Volume Configuration

```yaml
volumes:
  - name: config
    persistentVolumeClaim:
      claimName: radarr-config-iscsi-pvc
  - name: movie
    persistentVolumeClaim:
      claimName: movie-pvc
  - name: transmission
    persistentVolumeClaim:
      claimName: transmission-pvc
```

## Examples

### Basic Installation

```yaml
enabled: true

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: radarr.example.com
      paths:
        - path: /
          pathType: Prefix

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: radarr-config
  - name: movies
    persistentVolumeClaim:
      claimName: movies
  - name: downloads
    hostPath:
      path: /mnt/downloads
```

### Production Configuration with OpenBao

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: TZ
    value: "UTC"

resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "2000m"

openbao:
  enabled: true
  address: "http://openbao.vault.svc.cluster.local:8200"
  role: "radarr"
  kvPath: "secret/media/radarr"
  serviceUrl: "http://radarr.media.svc.cluster.local:7878"

livenessProbe:
  initialDelaySeconds: 120
  periodSeconds: 60

readinessProbe:
  initialDelaySeconds: 60
  periodSeconds: 30
```

## Post-Installation

After installation, access Radarr at the configured ingress host or by port-forwarding:

```bash
kubectl port-forward svc/radarr 7878:7878
```

Then open your browser to `http://localhost:7878`

### First-Time Setup

1. Complete the Radarr setup wizard
2. Configure media management settings
3. Add indexers (or connect to Prowlarr)
4. Add download client (Transmission, SABnzbd, etc.)
5. Set up quality profiles
6. Add root folder pointing to your movie directory
7. Start adding movies!

## Integration with Other Services

### Prowlarr (Indexer Manager)

Prowlarr can automatically sync indexers to Radarr. Configure Prowlarr with Radarr's API key and URL.

### Jellyseerr/Overseerr (Request Management)

Use Jellyseerr or Overseerr to allow users to request movies. Configure with Radarr's API key and service URL.

### Download Clients

Radarr supports various download clients:
- Transmission
- qBittorrent
- SABnzbd
- NZBGet
- Deluge

Configure the download client in Radarr's settings under Download Clients.

## OpenBao API Key Synchronization

When enabled, the OpenBao integration automatically:

1. Extracts the Radarr API key from the configuration
2. Stores it in OpenBao at the specified KV path
3. Makes it available for other services (Jellyseerr, Prowlarr, etc.)

This eliminates manual API key management and enables automatic service discovery.

### Prerequisites for OpenBao Integration

1. OpenBao cluster running in your cluster
2. Kubernetes auth method configured in OpenBao
3. Role with appropriate permissions created
4. ServiceAccount with proper annotations

## Monitoring and Logs

To view Radarr logs:

```bash
kubectl logs -f deployment/radarr
```

## Troubleshooting

### Radarr Not Starting

Check pod status and logs:

```bash
kubectl get pods -l app.kubernetes.io/name=radarr
kubectl logs -f deployment/radarr
```

### Permission Issues

Ensure PUID and PGID match the ownership of your media directories:

```bash
env:
  - name: PUID
    value: "1000"  # Your user ID
  - name: PGID
    value: "1000"  # Your group ID
```

### Download Client Connection Issues

Verify the download client is accessible from Radarr:

```bash
kubectl exec -it deployment/radarr -- curl http://transmission:9091
```

### API Key Not Syncing to OpenBao

Check init container logs:

```bash
kubectl logs deployment/radarr -c openbao-api-key-sync
```

## Upgrading

### To 0.3.0

No breaking changes from previous versions.

## Backup

It's recommended to regularly backup:

1. The `/config` directory (contains database and settings)
2. Export your Radarr configuration periodically

## Uninstallation

```bash
helm uninstall radarr
```

Note: This will not delete PersistentVolumeClaims. Delete them manually if needed:

```bash
kubectl delete pvc radarr-config
```

## Support

For issues and questions:
- [Radarr Wiki](https://wiki.servarr.com/radarr)
- [Radarr Discord](https://radarr.video/discord)
- [Chart Repository Issues](https://github.com/your-repo/issues)

## License

This Helm chart is licensed under the Apache License 2.0.

Radarr is licensed under the GPL-3.0 License. See the [Radarr License](https://github.com/Radarr/Radarr/blob/develop/LICENSE) for details.

# Sonarr Helm Chart

![Version: 0.3.0](https://img.shields.io/badge/Version-0.3.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 4.0.11](https://img.shields.io/badge/AppVersion-4.0.11-informational?style=flat-square)

A Helm chart for deploying Sonarr on Kubernetes.

## Overview

[Sonarr](https://sonarr.tv/) is a PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favorite shows and will grab, sort, and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available.

This Helm chart deploys Sonarr on a Kubernetes cluster using the [LinuxServer.io Sonarr image](https://hub.docker.com/r/linuxserver/sonarr).

## Features

- Automatic TV show downloading and management
- Episode tracking and calendar
- Quality profile management
- Integration with download clients (SABnzbd, NZBGet, Transmission, etc.)
- Integration with media servers (Plex, Jellyfin, Emby)
- Season and series monitoring
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
helm install sonarr your-repo/sonarr
```

### Install with custom values

```bash
helm install sonarr your-repo/sonarr -f values.yaml
```

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `enabled` | Enable/disable the chart deployment | `false` |
| `replicaCount` | Number of Sonarr replicas | `1` |
| `image.repository` | Sonarr image repository | `linuxserver/sonarr` |
| `image.tag` | Image tag | `"4.0.11"` |
| `service.port` | Service port | `8989` |
| `env[].PUID` | User ID for file permissions | `1000` |
| `env[].PGID` | Group ID for file permissions | `100` |
| `env[].TZ` | Timezone | `Europe/Zurich` |

For a complete list of parameters, see [values.yaml](values.yaml).

## Storage Requirements

Sonarr requires persistent storage for:

1. **Configuration** (`/config`): Application configuration, database, and metadata
2. **TV Shows** (`/data/show`): TV show library directory
3. **Downloads** (`/data/downloads`): Download client directory

### Example Volume Configuration

```yaml
volumes:
  - name: config
    persistentVolumeClaim:
      claimName: sonarr-config
  - name: shows
    persistentVolumeClaim:
      claimName: tv-shows
  - name: downloads
    persistentVolumeClaim:
      claimName: downloads
```

## Examples

### Basic Installation

```yaml
enabled: true

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: sonarr.example.com
      paths:
        - path: /
          pathType: Prefix

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: sonarr-config
  - name: shows
    persistentVolumeClaim:
      claimName: tv-shows
  - name: downloads
    hostPath:
      path: /mnt/downloads
```

### Production Configuration

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

livenessProbe:
  initialDelaySeconds: 120
  periodSeconds: 60

readinessProbe:
  initialDelaySeconds: 60
  periodSeconds: 30
```

## Post-Installation

After installation, access Sonarr at the configured ingress host or by port-forwarding:

```bash
kubectl port-forward svc/sonarr 8989:8989
```

Then open your browser to `http://localhost:8989`

### First-Time Setup

1. Complete the Sonarr setup wizard
2. Configure media management settings
3. Add indexers (or connect to Prowlarr)
4. Add download client (Transmission, SABnzbd, etc.)
5. Set up quality profiles
6. Add root folder pointing to your TV shows directory
7. Connect to your media server (Plex, Jellyfin, etc.)
8. Start adding TV shows!

## Integration with Other Services

### Prowlarr (Indexer Manager)

Prowlarr can automatically sync indexers to Sonarr. Configure Prowlarr with Sonarr's API key and URL.

### Jellyseerr/Overseerr (Request Management)

Use Jellyseerr or Overseerr to allow users to request TV shows. Configure with Sonarr's API key and service URL.

### Download Clients

Sonarr supports various download clients:
- Transmission
- qBittorrent
- SABnzbd
- NZBGet
- Deluge

Configure the download client in Sonarr's settings under Download Clients.

### Media Servers

Sonarr can notify your media server when new episodes are available:
- Plex
- Jellyfin
- Emby
- Kodi

Configure your media server connection in Sonarr's Connect settings.

## Monitoring and Logs

To view Sonarr logs:

```bash
kubectl logs -f deployment/sonarr
```

## Troubleshooting

### Sonarr Not Starting

Check pod status and logs:

```bash
kubectl get pods -l app.kubernetes.io/name=sonarr
kubectl logs -f deployment/sonarr
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

Verify the download client is accessible from Sonarr:

```bash
kubectl exec -it deployment/sonarr -- curl http://transmission:9091
```

### Episodes Not Downloading

1. Check that your indexers are configured and working
2. Verify your quality profile matches available releases
3. Ensure the series is being monitored
4. Check Sonarr's activity queue for any errors

## Upgrading

### To 0.3.0

No breaking changes from previous versions.

## Backup

It's recommended to regularly backup:

1. The `/config` directory (contains database and settings)
2. Export your Sonarr configuration periodically

## Uninstallation

```bash
helm uninstall sonarr
```

Note: This will not delete PersistentVolumeClaims. Delete them manually if needed:

```bash
kubectl delete pvc sonarr-config
```

## Support

For issues and questions:
- [Sonarr Wiki](https://wiki.servarr.com/sonarr)
- [Sonarr Discord](https://sonarr.tv/discord)
- [Chart Repository Issues](https://github.com/your-repo/issues)

## License

This Helm chart is licensed under the Apache License 2.0.

Sonarr is licensed under the GPL-3.0 License. See the [Sonarr License](https://github.com/Sonarr/Sonarr/blob/develop/LICENSE) for details.

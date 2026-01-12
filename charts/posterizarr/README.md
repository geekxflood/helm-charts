# Posterizarr Helm Chart

Automated poster generation for media libraries with Web UI support for Plex, Jellyfin, and Emby.

## Overview

Posterizarr is a PowerShell script with a full Web UI that automates generating images for your media library. It fetches artwork from multiple sources including Fanart.tv, TMDB, TVDB, Plex, and IMDb, prioritizing textless images while allowing custom overlays and text additions.

## Features

- **Web-based interface** for settings management and monitoring
- **Multi-server support** for Plex, Jellyfin, and Emby
- **Kometa integration** with compatible folder structure
- **Smart automation** via Tautulli, Sonarr, and Radarr webhooks
- **Persistent storage** for configuration and generated assets

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PersistentVolume provisioner support (for persistence)

## Installation

### Add Helm Repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install Chart

```bash
helm install posterizarr geekxflood/posterizarr \
  --namespace media \
  --create-namespace \
  --set enabled=true \
  --set persistence.config.enabled=true \
  --set persistence.assets.enabled=true
```

## Configuration

### Key Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `enabled` | Enable/disable the deployment | `false` |
| `image.repository` | Container image repository | `ghcr.io/fscorrupt/posterizarr` |
| `image.tag` | Container image tag | `latest` |
| `service.port` | Service port | `8000` |
| `env` | Environment variables | See values.yaml |
| `persistence.config.enabled` | Enable config persistence | `false` |
| `persistence.assets.enabled` | Enable assets persistence | `false` |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone | `UTC` |
| `TERM` | Terminal type | `xterm` |
| `RUN_TIME` | Runtime configuration | `disabled` |
| `APP_PORT` | Application port override | `8000` |
| `DISABLE_UI` | Disable web interface | `false` |

### Persistence

Posterizarr requires persistent storage for:

- **config** (5Gi): Application configuration and state
- **assets** (50Gi): Generated poster images
- **assetsbackup** (20Gi): Backup of original assets
- **manualassets** (10Gi): Manually curated assets

Example persistence configuration:

```yaml
persistence:
  config:
    enabled: true
    storageClass: "nfs-client"
    size: 5Gi
  assets:
    enabled: true
    storageClass: "nfs-client"
    size: 50Gi
  assetsbackup:
    enabled: true
    storageClass: "nfs-client"
    size: 20Gi
  manualassets:
    enabled: true
    storageClass: "nfs-client"
    size: 10Gi
```

## Application Configuration

Posterizarr uses a JSON configuration file (`config.json`) that must be created in the `/config` directory. The configuration includes:

- API keys for TVDB, TMDB, Fanart.tv
- Server URLs for Plex/Jellyfin/Emby
- Asset paths and processing options
- Language preferences
- Notification settings

See the [official documentation](https://fscorrupt.github.io/posterizarr/configuration/) for detailed configuration options.

### Using ConfigMap for Configuration

To manage configuration via GitOps, you can mount a ConfigMap with your config.json:

```yaml
initContainers:
  - name: init-config
    image: alpine:latest
    command: ["/bin/sh", "-c"]
    args:
      - |
        if [ ! -f /config/config.json ]; then
          echo "Copying default configuration..."
          cp /config-init/config.json /config/config.json
        fi
    volumeMounts:
      - name: config
        mountPath: /config
      - name: config-init
        mountPath: /config-init

volumes:
  - name: config-init
    configMap:
      name: posterizarr-custom-config
```

## Ingress Configuration

### Basic Ingress

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: posterizarr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: posterizarr-tls
      hosts:
        - posterizarr.example.com
```

### Cloudflare Tunnel

```yaml
cfTunnel:
  enabled: true
  tunnelRef:
    name: cloudflare-tunnel
  subjects:
    - kind: HTTPRoute
      name: posterizarr
```

## Upgrading

```bash
helm upgrade posterizarr geekxflood/posterizarr \
  --namespace media \
  --values values.yaml
```

## Uninstalling

```bash
helm uninstall posterizarr --namespace media
```

**Note**: PersistentVolumeClaims are not deleted automatically to prevent data loss. Delete them manually if needed:

```bash
kubectl delete pvc -n media -l app.kubernetes.io/name=posterizarr
```

## Resources

- [Posterizarr GitHub](https://github.com/fscorrupt/Posterizarr)
- [Configuration Documentation](https://fscorrupt.github.io/posterizarr/configuration/)
- [Helm Chart Repository](https://github.com/geekxflood/helm-charts)

## License

This Helm chart is provided under the MIT License. Posterizarr is licensed under GPL-3.0.

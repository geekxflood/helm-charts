# Audiobookshelf Helm Chart

![Version: 0.4.0](https://img.shields.io/badge/Version-0.4.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 2.30.0](https://img.shields.io/badge/AppVersion-2.30.0-informational?style=flat-square)

A Helm chart for deploying Audiobookshelf on Kubernetes.

## Overview

[Audiobookshelf](https://www.audiobookshelf.org/) is a self-hosted audiobook and podcast server. It allows you to manage your audiobook and podcast libraries, track listening progress, and stream content to various devices.

This Helm chart deploys Audiobookshelf on a Kubernetes cluster using the official [Audiobookshelf container image](https://github.com/advplyr/audiobookshelf).

## Features

- Stream audiobooks and podcasts
- Track listening progress across devices
- Mobile app support (iOS and Android)
- Podcast management with automatic downloads
- Multi-user support with progress sync
- OPDS feed support
- Chapter editor
- Metadata management

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Persistent storage for configuration and media files

## Installation

### Add the Helm repository

```bash
helm repo add your-repo https://your-repo-url
helm repo update
```

### Install the chart

```bash
helm install audiobookshelf your-repo/audiobookshelf
```

### Install with custom values

```bash
helm install audiobookshelf your-repo/audiobookshelf -f values.yaml
```

## Configuration

The following table lists the configurable parameters of the Audiobookshelf chart and their default values.

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `enabled` | Enable/disable the chart deployment | `false` |
| `replicaCount` | Number of Audiobookshelf replicas | `1` |

### Image Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Audiobookshelf image repository | `ghcr.io/advplyr/audiobookshelf` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `image.tag` | Image tag | `"2.30.0"` |
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
| `service.port` | Service port | `80` |

### Ingress Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class name | `cilium` |
| `ingress.annotations` | Ingress annotations | See values.yaml |
| `ingress.hosts` | Ingress hosts configuration | See values.yaml |
| `ingress.tls` | Ingress TLS configuration | See values.yaml |

### Resource Management

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources` | Resource requests and limits | `{}` |

### Autoscaling Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable horizontal pod autoscaler | `false` |

### Storage Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `volumes` | Volume definitions | See values.yaml |
| `volumeMounts` | Volume mount definitions | See values.yaml |

## Storage Requirements

Audiobookshelf requires persistent storage for:

1. **Configuration** (`/config`): Application configuration and database
2. **Metadata** (`/metadata`): Book covers and metadata cache
3. **Audiobooks** (`/data/audiobooks`): Your audiobook library

### Default Volume Configuration

The chart includes three volumes by default:

```yaml
volumes:
  - name: config
    persistentVolumeClaim:
      claimName: audiobookshelf-config-iscsi-pvc
  - name: metadata
    emptyDir: {}
  - name: audiobooks
    persistentVolumeClaim:
      claimName: audiobooks-pvc
```

## Examples

### Basic Installation

```yaml
enabled: true

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: audiobookshelf-config
  - name: metadata
    emptyDir: {}
  - name: audiobooks
    hostPath:
      path: /mnt/audiobooks
```

### Installation with Custom Environment

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: TZ
    value: "America/New_York"

resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

### Installation with Ingress and TLS

```yaml
enabled: true

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
  hosts:
    - host: audiobooks.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - audiobooks.example.com
      secretName: audiobooks-tls
```

### Production Configuration

```yaml
enabled: true

replicaCount: 1

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

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: audiobookshelf-config
  - name: metadata
    persistentVolumeClaim:
      claimName: audiobookshelf-metadata
  - name: audiobooks
    persistentVolumeClaim:
      claimName: audiobooks-library

volumeMounts:
  - name: config
    mountPath: /config
  - name: metadata
    mountPath: /metadata
  - name: audiobooks
    mountPath: /audiobooks
```

## Post-Installation

After installation, you can access Audiobookshelf at the configured ingress host or by port-forwarding:

```bash
kubectl port-forward svc/audiobookshelf 13378:80
```

Then open your browser to `http://localhost:13378`

### First-Time Setup

1. Create your admin account on first login
2. Add your audiobook libraries by pointing to the mounted volumes
3. Configure your preferred settings (timezone, language, etc.)
4. Optionally set up podcast feeds

## Mobile Apps

Audiobookshelf has official mobile apps available:

- **iOS**: [App Store](https://apps.apple.com/us/app/audiobookshelf/id1614635225)
- **Android**: [Google Play](https://play.google.com/store/apps/details?id=com.audiobookshelf.app)

## Upgrading

### To 0.4.0

No breaking changes from previous versions.

## Backup

It's recommended to regularly backup:

1. The `/config` directory (contains database and user data)
2. The `/metadata` directory (contains covers and cached metadata)

## Troubleshooting

### Permission Issues

If you encounter permission issues with mounted volumes, ensure that the PUID and PGID environment variables match the ownership of your media files:

```yaml
env:
  - name: PUID
    value: "1000"  # Your user ID
  - name: PGID
    value: "1000"  # Your group ID
```

### Audio Streaming Issues

Ensure your ingress is configured to handle long-running connections for audio streaming. For Nginx Ingress, add:

```yaml
ingress:
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```

## Uninstallation

```bash
helm uninstall audiobookshelf
```

Note: This will not delete PersistentVolumeClaims. Delete them manually if needed:

```bash
kubectl delete pvc audiobookshelf-config
```

## Support

For issues and questions:
- [Audiobookshelf Documentation](https://www.audiobookshelf.org/)
- [Audiobookshelf GitHub](https://github.com/advplyr/audiobookshelf)
- [Chart Repository Issues](https://github.com/your-repo/issues)

## License

This Helm chart is licensed under the Apache License 2.0.

Audiobookshelf is licensed under the GPL-3.0 License. See the [Audiobookshelf License](https://github.com/advplyr/audiobookshelf/blob/master/LICENSE) for details.

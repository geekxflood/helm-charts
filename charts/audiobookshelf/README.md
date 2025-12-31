# Audiobookshelf Helm Chart

![Version: 0.5.0](https://img.shields.io/badge/Version-0.5.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

Infrastructure-agnostic Helm chart for deploying Audiobookshelf on Kubernetes.

## Overview

[Audiobookshelf](https://www.audiobookshelf.org/) is a self-hosted audiobook and podcast server. It allows you to manage your audiobook and podcast libraries, track listening progress, and stream content to various devices.

## Features

- 📚 Stream audiobooks and podcasts
- 📊 Track listening progress across devices
- 📱 Mobile app support (iOS and Android)
- 🎙️ Podcast management with automatic downloads
- 👥 Multi-user support with progress sync
- 📖 OPDS feed support
- ✂️ Chapter editor
- 🔍 Metadata management

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Persistent storage for configuration and media files

## Installation

### Via ArgoCD (Recommended)

This chart is deployed via ArgoCD Application manifest with infrastructure-specific overrides:

```bash
kubectl apply -f argocd/apps/media/audiobookshelf.yaml
```

### Manual Installation

```bash
helm install audiobookshelf . \
  --namespace media \
  --create-namespace \
  --values your-values.yaml
```

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `enabled` | Enable/disable the chart deployment | `true` |
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image repository | `ghcr.io/advplyr/audiobookshelf` |
| `image.tag` | Container image tag | `latest` |
| `service.port` | Service port | `80` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `cfTunnel.enabled` | Enable CloudFlare Tunnel | `false` |
| `persistence.config.enabled` | Enable config PVC | `true` |
| `persistence.config.size` | Config PVC size | `5Gi` |
| `persistence.config.storageClass` | Storage class for config | `""` |
| `persistence.metadata.enabled` | Enable metadata PVC | `true` |
| `persistence.metadata.size` | Metadata PVC size | `10Gi` |
| `persistence.metadata.storageClass` | Storage class for metadata | `""` |

### Storage

The chart creates two PVCs by default:
- **config**: Application configuration and database (`/config`)
- **metadata**: Audiobook metadata, covers, and cache (`/metadata`)

Additional volumes for media libraries should be configured via `volumes` and `volumeMounts` arrays.

### Infrastructure-Specific Configuration

This chart is **infrastructure-agnostic**. All infrastructure-specific values should be provided via:
- ArgoCD Application `helm.values` overrides
- Custom values files (`-f values.yaml`)
- `--set` flags

**Example: Infrastructure-specific overrides in ArgoCD**

```yaml
spec:
  source:
    helm:
      values: |
        ingress:
          enabled: true
          className: cilium
          annotations:
            cert-manager.io/cluster-issuer: letsencrypt-prod
            ingress.cilium.io/loadbalancer-mode: shared
          hosts:
            - host: audiobook.example.com
              paths:
                - path: /
                  pathType: Prefix
          tls:
            - secretName: audiobookshelf-tls
              hosts:
                - audiobook.example.com

        persistence:
          config:
            storageClass: "your-storage-class"
          metadata:
            storageClass: "your-storage-class"

        env:
          - name: TZ
            value: "America/New_York"
          - name: AUDIOBOOKSHELF_UID
            value: "1000"
          - name: AUDIOBOOKSHELF_GID
            value: "100"

        volumes:
          - name: audiobooks
            persistentVolumeClaim:
              claimName: audiobooks-pvc

        volumeMounts:
          - name: audiobooks
            mountPath: /audiobooks
```

### Health Probes

The chart includes default liveness and readiness probes:

```yaml
livenessProbe:
  httpGet:
    path: /healthcheck
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /healthcheck
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
```

## Post-Installation

After installation, access Audiobookshelf at the configured ingress host or by port-forwarding:

```bash
kubectl port-forward -n media svc/audiobookshelf 13378:80
```

Then open `http://localhost:13378`

### First-Time Setup

1. Create admin account on first login
2. Add audiobook libraries pointing to mounted volumes
3. Configure preferred settings (timezone, language, etc.)
4. Optionally add podcast feeds

## Mobile Apps

- **iOS**: [App Store](https://apps.apple.com/us/app/audiobookshelf/id1614635225)
- **Android**: [Google Play](https://play.google.com/store/apps/details?id=com.audiobookshelf.app)

## Backup

Regularly backup:
1. `/config` directory (database and user data)
2. `/metadata` directory (covers and cached metadata)

## Troubleshooting

### Permission Issues

Ensure PUID and PGID environment variables match your media file ownership:

```yaml
env:
  - name: AUDIOBOOKSHELF_UID
    value: "1000"
  - name: AUDIOBOOKSHELF_GID
    value: "100"
```

### Audio Streaming Issues

Configure ingress for long-running connections. Example for Nginx Ingress:

```yaml
ingress:
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```

## Uninstallation

```bash
helm uninstall audiobookshelf -n media
```

Note: PersistentVolumeClaims are not automatically deleted.

## References

- [Website](https://www.audiobookshelf.org/)
- [GitHub](https://github.com/advplyr/audiobookshelf)
- [Documentation](https://www.audiobookshelf.org/docs)

## License

This Helm chart is licensed under the Apache License 2.0.

Audiobookshelf is licensed under GPL-3.0. See the [Audiobookshelf License](https://github.com/advplyr/audiobookshelf/blob/master/LICENSE) for details.

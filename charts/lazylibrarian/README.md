# LazyLibrarian Helm Chart

This Helm chart deploys LazyLibrarian, an automated ebook and audiobook management application for Kubernetes.

## Overview

LazyLibrarian is a program to follow authors and grab metadata for all your digital reading needs. It uses a combination of Goodreads, LibraryThing, and optionally GoogleBooks as sources for author information and book details.

## Features

- **Automated Downloads**: Automatically search and download ebooks and audiobooks when new releases are available
- **Author Tracking**: Follow your favorite authors and get notified of new releases
- **Multiple Metadata Sources**: Integrates with Goodreads, LibraryThing, and GoogleBooks
- **Download Client Support**: Works with Usenet (SABnzbd, NZBGet) and Torrent (Deluge, qBittorrent, Transmission) downloaders
- **Calibre Integration**: Seamless integration with Calibre for ebook library management
- **Audiobook Support**: Full audiobook management with FFmpeg for format conversion
- **Magazine Support**: Download and organize magazines automatically

## Prerequisites

- Kubernetes cluster
- Helm 3+
- Storage provisioner (for persistent storage)
- Optional: Download client (SABnzbd, NZBGet, Deluge, qBittorrent, etc.)
- Optional: Prowlarr for indexer management

## Installation

### Basic Installation

```bash
helm install lazylibrarian ./charts/lazylibrarian
```

### Installation with Custom Values

```bash
helm install lazylibrarian ./charts/lazylibrarian \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=lazylibrarian.example.com
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | LazyLibrarian image repository | `lscr.io/linuxserver/lazylibrarian` |
| `image.tag` | Image tag | `latest` |
| `service.port` | Service port | `5299` |
| `persistence.enabled` | Enable persistent storage | `false` |
| `persistence.size` | Storage size | `10Gi` |
| `ingress.enabled` | Enable ingress | `false` |
| `env` | Environment variables | See values.yaml |

### Environment Variables

The chart configures the following environment variables by default:

```yaml
env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: TZ
    value: "UTC"
```

### Optional Docker Mods

Enable Calibre database import and FFmpeg audiobook conversion:

```yaml
env:
  - name: DOCKER_MODS
    value: "linuxserver/mods:universal-calibre|linuxserver/mods:lazylibrarian-ffmpeg"
```

### Persistent Storage

Enable persistent storage for configuration:

```yaml
persistence:
  enabled: true
  size: 10Gi
  storageClass: "your-storage-class"
```

### Additional Volumes

Mount additional volumes for books and downloads:

```yaml
volumes:
  - name: books
    persistentVolumeClaim:
      claimName: books-pvc
  - name: downloads
    persistentVolumeClaim:
      claimName: downloads-pvc

volumeMounts:
  - name: books
    mountPath: /books
  - name: downloads
    mountPath: /downloads
```

### Ingress Configuration

Enable ingress for external access:

```yaml
ingress:
  enabled: true
  className: cilium
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: lazylibrarian.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: lazylibrarian-tls
      hosts:
        - lazylibrarian.example.com
```

### CloudFlare Tunnel Support

Enable CloudFlare Tunnel for public access:

```yaml
cfTunnel:
  enabled: true
  tunnelRef:
    kind: ClusterTunnel
    name: cloudflare-tunnel
  subjects:
    - name: lazylibrarian
      spec:
        fqdn: lazylibrarian.example.com
        protocol: http
```

### OpenBao Integration

Enable OpenBao for API key management:

```yaml
openbao:
  enabled: true
  address: "https://openbao.example.com"
  authMount: "kubernetes"
  role: "lazylibrarian"
  kvPath: "secret/media/lazylibrarian"
  serviceUrl: "http://lazylibrarian:5299"
```

## Integration with Download Clients

LazyLibrarian works with various download clients:

### Usenet Clients

- **SABnzbd**: Configure in Settings → Download Settings
- **NZBGet**: Configure in Settings → Download Settings

### Torrent Clients

- **Deluge**: Configure in Settings → Download Settings
- **qBittorrent**: Configure in Settings → Download Settings
- **Transmission**: Configure in Settings → Download Settings

### Indexer Management

Use Prowlarr for centralized indexer management. Configure Prowlarr to sync indexers to LazyLibrarian automatically.

## Integration with Calibre

LazyLibrarian can integrate with Calibre for library management:

1. Enable the Calibre Docker mod (see Optional Docker Mods above)
2. Configure Calibre library path in LazyLibrarian settings
3. LazyLibrarian will import existing Calibre metadata and add new books to the library

## Upgrading

```bash
helm upgrade lazylibrarian ./charts/lazylibrarian
```

## Uninstalling

```bash
helm uninstall lazylibrarian
```

## Troubleshooting

### Checking Logs

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=lazylibrarian
```

### Accessing the Pod

```bash
kubectl exec -n <namespace> -it <pod-name> -- /bin/bash
```

### Common Issues

**Port Already in Use**: Check if another service is using port 5299

**Storage Issues**: Ensure PVC is bound and accessible

**Download Client Connection**: Verify download client URL and credentials

## Links

- [LazyLibrarian Documentation](https://lazylibrarian.gitlab.io/)
- [LazyLibrarian GitLab](https://gitlab.com/LazyLibrarian/LazyLibrarian)
- [LinuxServer.io LazyLibrarian Image](https://docs.linuxserver.io/images/docker-lazylibrarian/)
- [Docker Hub](https://hub.docker.com/r/linuxserver/lazylibrarian)

## License

This chart is provided as-is for use with the GXF Kubernetes Cluster.

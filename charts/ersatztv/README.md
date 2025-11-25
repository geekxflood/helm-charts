# ErsatzTV Helm Chart

This Helm chart deploys [ErsatzTV](https://ersatztv.org/) on Kubernetes. ErsatzTV is software for configuring and streaming custom live TV channels using your media library.

## Features

- Custom live TV channels from your media library
- Schedule content and create playlists
- IPTV streaming support
- Hardware transcoding with GPU support (optional)
- Integration with Plex, Jellyfin, and Emby media servers
- Web-based UI for channel management

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PersistentVolume provisioner support (Longhorn, NFS, etc.)
- Access to media library PVCs (movies, TV shows, etc.)

## Installation

### Basic Installation

```bash
helm install ersatztv charts/ersatztv
```

### With Custom Values

```bash
helm install ersatztv charts/ersatztv -f custom-values.yaml
```

## Configuration

### Required Configuration

You **must** configure volume mounts for your media library in `values.yaml`:

```yaml
volumes:
  - name: config
    persistentVolumeClaim:
      claimName: ersatztv-config-pvc
  - name: movies
    persistentVolumeClaim:
      claimName: movie-pvc
  - name: shows
    persistentVolumeClaim:
      claimName: show-pvc

volumeMounts:
  - name: config
    mountPath: /config
  - name: movies
    mountPath: /media/movies
    readOnly: true
  - name: shows
    mountPath: /media/shows
    readOnly: true
```

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | ErsatzTV image repository | `ghcr.io/ersatztv/ersatztv` |
| `image.tag` | Image tag | `latest` |
| `service.port` | Service port | `8409` |
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class name | `cilium` |
| `ingress.hosts[0].host` | Hostname | `ersatztv.local.geekxflood.io` |
| `gpu.enabled` | Enable GPU hardware acceleration | `false` |
| `gpu.runtimeClass` | GPU runtime class | `nvidia` |
| `env[0].name` | Timezone variable | `TZ` |
| `env[0].value` | Timezone value | `America/Chicago` |

### Hardware Acceleration (GPU)

To enable GPU hardware transcoding:

```yaml
gpu:
  enabled: true
  runtimeClass: nvidia
  count: 1

nodeSelector:
  nvidia.com/gpu.present: "true"
```

**Note:** Hardware acceleration only works on Linux hosts. It is not supported in Docker Desktop on Windows/macOS.

### Transcoding tmpfs

To reduce SSD writes during transcoding, enable tmpfs:

```yaml
tmpfs:
  enabled: true
  sizeLimit: 10Gi
```

## Usage

After deployment, access ErsatzTV at the configured ingress hostname:

```
https://ersatztv.local.geekxflood.io
```

### Initial Setup

1. Access the web UI
2. Configure media sources (Plex, Jellyfin, Emby, or local files)
3. Create channels and add content
4. Set up schedules and playlists
5. Access streams via IPTV clients

### IPTV Integration

ErsatzTV provides M3U playlists and XMLTV EPG data for use with IPTV clients:

- **M3U Playlist:** `http://ersatztv.local.geekxflood.io:8409/iptv/channels.m3u`
- **XMLTV EPG:** `http://ersatztv.local.geekxflood.io:8409/iptv/xmltv.xml`

## Storage

ErsatzTV requires persistent storage for:

- Configuration database (`/config`)
- FFmpeg cache and logs
- Channel artwork and metadata

The default PVC is created with:
- **Size:** 10Gi
- **StorageClass:** longhorn
- **AccessMode:** ReadWriteOnce

## Resources

Default resource limits:

```yaml
resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

Adjust based on your transcoding needs and number of concurrent streams.

## Upgrading

ErsatzTV **does not support downgrades**. Always backup your configuration before upgrading:

```bash
# Backup config PVC before upgrade
kubectl exec -n <namespace> <pod-name> -- tar czf /tmp/config-backup.tar.gz /config

# Upgrade
helm upgrade ersatztv charts/ersatztv
```

## Troubleshooting

### Pod Won't Start

Check logs:
```bash
kubectl logs -n <namespace> <pod-name>
```

Common issues:
- Insufficient memory (increase resource limits)
- Missing media volume mounts
- Incorrect PVC claims

### Streams Not Working

- Verify FFmpeg is working inside the pod
- Check transcoding settings in ErsatzTV UI
- Ensure media files are accessible at mounted paths
- Check GPU availability if using hardware acceleration

## Documentation

- [ErsatzTV Official Docs](https://ersatztv.org/docs/)
- [GitHub Repository](https://github.com/ErsatzTV/ErsatzTV)
- [Discord Community](https://discord.gg/hHiJm3p3FD)

## License

This Helm chart is provided as-is. ErsatzTV is licensed under the [MIT License](https://github.com/ErsatzTV/ErsatzTV/blob/main/LICENSE).

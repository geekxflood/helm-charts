# Bazarr Helm Chart

This Helm chart deploys Bazarr, a companion application to Sonarr and Radarr that manages and downloads subtitles based on your requirements.

## Overview

**Bazarr** is a subtitle management tool that:
- Automatically downloads subtitles for your media library
- Integrates with Sonarr (TV shows) and Radarr (movies)
- Supports multiple subtitle providers
- Offers advanced subtitle matching and synchronization

## Prerequisites

Before deploying Bazarr, ensure you have:

1. **Synology NAS LUN created** for Bazarr config storage (50GB recommended)
2. **Shared media volumes** available:
   - `show-pvc` - TV shows library (shared with Sonarr)
   - `anime-pvc` - Anime library
   - `movie-pvc` - Movies library (shared with Radarr)
3. **DNS configured** for `bazarr.local.geekxflood.io`
4. **cert-manager** installed with Let's Encrypt issuer

## Chart Structure

```
bazarr/
├── Chart.yaml                 # Chart metadata
├── values.yaml                # Configuration values
├── templates/
│   ├── deployment.yaml        # Main deployment
│   ├── service.yaml          # ClusterIP service
│   ├── ingress.yaml          # Traefik ingress with TLS
│   ├── pvc.yaml              # Config storage claim
│   ├── serviceaccount.yaml   # Service account
│   └── _helpers.tpl          # Template helpers
└── README.md                 # This file
```

## Configuration

### Image

```yaml
image:
  repository: linuxserver/bazarr
  pullPolicy: Always
  tag: latest
```

### Environment Variables

```yaml
env:
  - name: PUID          # User ID for file permissions
    value: 1000
  - name: PGID          # Group ID for file permissions
    value: 100
  - name: TZ            # Timezone
    value: Europe/Zurich
```

### Storage

Bazarr requires persistent storage for:
- **Configuration**: Stores application config, database, and logs
- **Media libraries**: Read-only access to media files for subtitle management

#### Config Storage (iSCSI)

```yaml
volumes:
  - name: config
    persistentVolumeClaim:
      claimName: bazarr-config-iscsi-pvc
```

**PVC Specification**:
- Storage Class: `synology-csi-driver-iscsi-retain`
- Access Mode: `ReadWriteOnce`
- Size: `50Gi`

#### Shared Media Volumes (NFS)

```yaml
volumes:
  - name: show
    persistentVolumeClaim:
      claimName: show-pvc      # Shared with Sonarr
  - name: anime
    persistentVolumeClaim:
      claimName: anime-pvc
  - name: movie
    persistentVolumeClaim:
      claimName: movie-pvc     # Shared with Radarr
```

**Volume Mounts**:
```yaml
volumeMounts:
  - name: config
    mountPath: /config
  - name: show
    mountPath: /data/show
  - name: anime
    mountPath: /data/anime
  - name: movie
    mountPath: /data/movie
```

### Network Access

**Service**:
- Type: `ClusterIP`
- Port: `6767`

**Ingress**:
- URL: `https://bazarr.local.geekxflood.io`
- TLS: Automated via cert-manager with Let's Encrypt
- Ingress Class: Traefik

### Health Checks

**Liveness Probe**:
- Endpoint: `HTTP GET /`
- Initial Delay: 60 seconds
- Period: 60 seconds
- Timeout: 5 seconds

**Readiness Probe**:
- Endpoint: `HTTP GET /`
- Initial Delay: 30 seconds
- Period: 30 seconds
- Timeout: 5 seconds

## Installation

### Step 1: Create Synology LUN

1. Log into Synology DSM
2. Go to **Storage Manager** > **iSCSI** > **LUN**
3. Create a new LUN:
   - Name: `bazarr-config`
   - Size: `50GB`
   - Allocation: Thick provisioning (recommended)
4. Note the LUN target IQN for Kubernetes CSI driver

### Step 2: Verify Shared Volumes

Ensure the shared media PVCs exist:

```bash
kubectl get pvc -n media show-pvc anime-pvc movie-pvc
```

### Step 3: Deploy Bazarr

From the chart directory:

```bash
cd /home/cri/infra/kube-deployment/media/charts/bazarr
helm install bazarr . --namespace media --create-namespace
```

Or from the repository root:

```bash
helm install bazarr media/charts/bazarr --namespace media
```

### Step 4: Verify Deployment

Check pod status:

```bash
kubectl get pods -n media -l app.kubernetes.io/name=bazarr
```

Check if PVC is bound:

```bash
kubectl get pvc -n media bazarr-config-iscsi-pvc
```

View logs:

```bash
kubectl logs -n media -l app.kubernetes.io/name=bazarr -f
```

### Step 5: Access Bazarr

Open your browser and navigate to:
```
https://bazarr.local.geekxflood.io
```

## Post-Deployment Configuration

### Initial Setup

1. **Access Bazarr** via `https://bazarr.local.geekxflood.io`
2. **Set up authentication** (recommended)
3. **Configure Sonarr integration**:
   - URL: `http://sonarr.media.svc.cluster.local:8989`
   - API Key: Get from Sonarr settings
4. **Configure Radarr integration**:
   - URL: `http://radarr.media.svc.cluster.local:7878`
   - API Key: Get from Radarr settings
5. **Add subtitle providers** (OpenSubtitles, Subscene, etc.)
6. **Configure languages** for subtitle downloads

### Path Mappings

Ensure path mappings match your volume mounts:

**For Sonarr**:
- Sonarr path: `/data/show` or `/data/anime`
- Bazarr path: `/data/show` or `/data/anime`

**For Radarr**:
- Radarr path: `/data/movie`
- Bazarr path: `/data/movie`

## Upgrading

```bash
cd /home/cri/infra/kube-deployment/media/charts/bazarr
helm upgrade bazarr . --namespace media
```

## Uninstalling

```bash
helm uninstall bazarr --namespace media
```

**Note**: This will not delete the PVC. To also delete the persistent volume:

```bash
kubectl delete pvc -n media bazarr-config-iscsi-pvc
```

## Troubleshooting

### Pod Not Starting

Check pod events:
```bash
kubectl describe pod -n media -l app.kubernetes.io/name=bazarr
```

Common issues:
- PVC not bound (check Synology LUN is available)
- Image pull errors (check network connectivity)
- Resource constraints (check node resources)

### Cannot Access Web UI

1. Check ingress:
   ```bash
   kubectl get ingress -n media bazarr
   ```

2. Verify certificate:
   ```bash
   kubectl get certificate -n media bazarr-local-geekxflood-io-tls
   ```

3. Check Traefik logs:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
   ```

### Subtitle Downloads Not Working

1. **Check Sonarr/Radarr connectivity**:
   ```bash
   kubectl exec -n media deploy/bazarr -- wget -O- http://sonarr.media.svc.cluster.local:8989
   ```

2. **Verify path mappings** in Bazarr settings
3. **Check provider credentials** (if required)
4. **Review Bazarr logs**:
   ```bash
   kubectl logs -n media deploy/bazarr | grep -i error
   ```

### Permission Issues

If you see permission errors in logs:

1. Verify PUID/PGID match your NFS user:
   ```yaml
   env:
     - name: PUID
       value: 1000  # Should match NFS UID
     - name: PGID
       value: 100   # Should match NFS GID
   ```

2. Check NFS export permissions on Synology

## Integration with Other Services

Bazarr works in conjunction with:

- **Sonarr**: Manages TV show subtitles
- **Radarr**: Manages movie subtitles
- **Plex**: Serves media with downloaded subtitles
- **Prowlarr**: Can share indexers (optional)

## Resources

- **Default Resources**: No limits set (uses namespace defaults)
- **Recommended**:
  ```yaml
  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi
      cpu: 500m
  ```

## Version History

- **v0.2.0**: Added health probes, updated to latest image tag
- **v0.1.0**: Initial chart creation

## References

- [Bazarr Documentation](https://wiki.bazarr.media/)
- [LinuxServer.io Bazarr Image](https://docs.linuxserver.io/images/docker-bazarr/)
- [Bazarr GitHub](https://github.com/morpheus65535/bazarr)

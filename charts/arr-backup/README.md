# arr-backup

Automated backup solution for Radarr, Sonarr, Prowlarr, and Bazarr using their native backup APIs.

## Overview

This Helm chart deploys a Kubernetes CronJob that:

1. Runs on a scheduled basis (default: 2 AM daily)
2. Triggers backup operations via each application's API
3. Downloads the generated backup archives
4. Stores backups on a persistent volume (Synology NFS)
5. Optionally cleans up old backups based on retention policy

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Running instances of Radarr, Sonarr, Prowlarr, and/or Bazarr
- API keys for each application
- Storage solution (Synology NFS via CSI or direct NFS mount)

## Installation

### 1. Create a Secret for API Keys (Recommended)

Create a Kubernetes secret containing your API keys:

```bash
kubectl create secret generic arr-backup-secrets \
  --namespace=media \
  --from-literal=radarr-api-key=YOUR_RADARR_API_KEY \
  --from-literal=sonarr-api-key=YOUR_SONARR_API_KEY \
  --from-literal=prowlarr-api-key=YOUR_PROWLARR_API_KEY \
  --from-literal=bazarr-api-key=YOUR_BAZARR_API_KEY
```

Or use Sealed Secrets/External Secrets Operator for GitOps workflows.

### 2. Install the Chart

#### Using existing secret (recommended):

```bash
helm install arr-backup ./charts/arr-backup \
  --namespace media \
  --set existingSecret=arr-backup-secrets \
  --set services.radarr.url=http://radarr.media.svc.cluster.local:7878 \
  --set services.sonarr.url=http://sonarr.media.svc.cluster.local:8989 \
  --set services.prowlarr.url=http://prowlarr.media.svc.cluster.local:9696 \
  --set services.bazarr.url=http://bazarr.media.svc.cluster.local:6767
```

#### Using values in chart (less secure):

Create a `custom-values.yaml`:

```yaml
existingSecret: ""

services:
  radarr:
    enabled: true
    url: "http://radarr.media.svc.cluster.local:7878"
    apiKey: "your-radarr-api-key"

  sonarr:
    enabled: true
    url: "http://sonarr.media.svc.cluster.local:8989"
    apiKey: "your-sonarr-api-key"

  prowlarr:
    enabled: true
    url: "http://prowlarr.media.svc.cluster.local:9696"
    apiKey: "your-prowlarr-api-key"

  bazarr:
    enabled: true
    url: "http://bazarr.media.svc.cluster.local:6767"
    apiKey: "your-bazarr-api-key"

storage:
  storageClassName: "synology-nfs-storage"

schedule: "0 2 * * *"  # 2 AM daily
timezone: "America/New_York"
```

Install with custom values:

```bash
helm install arr-backup ./charts/arr-backup \
  --namespace media \
  --values custom-values.yaml
```

## Configuration

### Storage Options

#### Option 1: Synology CSI (Recommended)

Use the Synology CSI driver to dynamically provision storage:

```yaml
storage:
  storageClassName: "synology-nfs-storage"
  accessMode: ReadWriteMany
  size: 10Gi
  existingPvc: ""
  nfs:
    enabled: false
```

#### Option 2: Direct NFS Mount

Mount NFS directly without using a PVC:

```yaml
storage:
  nfs:
    enabled: true
    server: "192.168.1.100"  # Your Synology NAS IP
    path: "/volume1/media/backup"
```

#### Option 3: Use Existing PVC

If you already have a PVC created:

```yaml
storage:
  existingPvc: "my-backup-pvc"
```

### Service Configuration

Enable or disable backup for specific services:

```yaml
services:
  radarr:
    enabled: true
    url: "http://radarr.media.svc.cluster.local:7878"
    apiKey: ""  # Use existingSecret instead

  sonarr:
    enabled: false  # Disable Sonarr backup

  prowlarr:
    enabled: true
    url: "http://prowlarr.media.svc.cluster.local:9696"
    apiKey: ""

  bazarr:
    enabled: true
    url: "http://bazarr.media.svc.cluster.local:6767"
    apiKey: ""
```

### Backup Schedule

Customize the backup schedule using standard cron syntax:

```yaml
# Run daily at 2 AM
schedule: "0 2 * * *"

# Run twice daily at 2 AM and 2 PM
schedule: "0 2,14 * * *"

# Run weekly on Sunday at 3 AM
schedule: "0 3 * * 0"

# Timezone for the schedule
timezone: "America/New_York"
```

### Retention Policy

Configure automatic cleanup of old backups:

```yaml
retention:
  enabled: true
  days: 30  # Keep backups for 30 days
```

To keep all backups indefinitely:

```yaml
retention:
  enabled: false
```

### Resource Limits

Adjust resource limits for the backup job:

```yaml
resources:
  limits:
    cpu: 200m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 64Mi
```

## How It Works

### Backup Process

1. **CronJob Trigger**: At the scheduled time, Kubernetes launches a job
2. **API Call**: The script calls each enabled service's `/api/v3/system/backup` endpoint
3. **Backup Generation**: Each application generates a backup archive
4. **Download**: The script retrieves the backup files
5. **Storage**: Backups are stored in the configured NFS volume with timestamp
6. **Cleanup**: If retention is enabled, old backups are removed
7. **Logging**: Detailed logs are available via `kubectl logs`

### API Endpoints Used

- **Radarr**: `POST /api/v3/system/backup` and `GET /api/v3/system/backup/{id}/download`
- **Sonarr**: `POST /api/v3/system/backup` and `GET /api/v3/system/backup/{id}/download`
- **Prowlarr**: `POST /api/v3/system/backup` and `GET /api/v3/system/backup/{id}/download`
- **Bazarr**: `POST /api/v3/system/backup` and `GET /api/v3/system/backup/{id}/download`

## Troubleshooting

### Check CronJob Status

```bash
kubectl get cronjobs -n media
kubectl get jobs -n media
```

### View Backup Logs

```bash
# Get the most recent job
kubectl get jobs -n media --sort-by=.metadata.creationTimestamp

# View logs
kubectl logs -n media job/arr-backup-<job-id>
```

### Manually Trigger a Backup

```bash
kubectl create job --from=cronjob/arr-backup arr-backup-manual -n media
```

### Check Backup Files

```bash
# Access the backup volume
kubectl run -n media -it --rm debug --image=busybox --restart=Never -- sh

# Mount the backup PVC
kubectl debug -n media -it pod/radarr --image=busybox --share-processes --copy-to=backup-debug
```

### Common Issues

#### API Key Issues

**Error**: `✗ Service: Skipped (no API key provided)`

**Solution**: Ensure your secret contains the correct keys and the secret name matches `existingSecret` value.

#### Connection Issues

**Error**: `✗ Service: Backup trigger failed (HTTP 000)`

**Solution**: Check that the service URL is correct and the service is reachable from the backup pod.

#### Storage Issues

**Error**: `cannot create directory: Read-only file system`

**Solution**: Check PVC/NFS permissions. Ensure the pod's fsGroup matches the NFS export permissions.

## ArgoCD Deployment

To deploy this chart via ArgoCD, create an Application manifest in your `kube-deployment` repository:

```yaml
# kube-deployment/argocd/applications/media/arr-backup.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: arr-backup
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://geekxflood.github.io/helm-charts
    path: charts/arr-backup
    targetRevision: HEAD
    helm:
      values: |
        existingSecret: arr-backup-secrets

        services:
          radarr:
            enabled: true
            url: "http://radarr.media.svc.cluster.local:7878"
          sonarr:
            enabled: true
            url: "http://sonarr.media.svc.cluster.local:8989"
          prowlarr:
            enabled: true
            url: "http://prowlarr.media.svc.cluster.local:9696"
          bazarr:
            enabled: true
            url: "http://bazarr.media.svc.cluster.local:6767"

        storage:
          storageClassName: "synology-nfs-storage"

        schedule: "0 2 * * *"
        timezone: "America/New_York"

        retention:
          enabled: true
          days: 30

  destination:
    server: https://kubernetes.default.svc
    namespace: media

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Values Reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `schedule` | Cron schedule for backup job | `"0 2 * * *"` |
| `timezone` | Timezone for cron schedule | `"America/New_York"` |
| `image.repository` | Container image repository | `curlimages/curl` |
| `image.tag` | Container image tag | `"8.5.0"` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `services.radarr.enabled` | Enable Radarr backups | `true` |
| `services.radarr.url` | Radarr service URL | `"http://radarr.media.svc.cluster.local:7878"` |
| `services.radarr.apiKey` | Radarr API key (use existingSecret) | `""` |
| `services.sonarr.enabled` | Enable Sonarr backups | `true` |
| `services.sonarr.url` | Sonarr service URL | `"http://sonarr.media.svc.cluster.local:8989"` |
| `services.sonarr.apiKey` | Sonarr API key (use existingSecret) | `""` |
| `services.prowlarr.enabled` | Enable Prowlarr backups | `true` |
| `services.prowlarr.url` | Prowlarr service URL | `"http://prowlarr.media.svc.cluster.local:9696"` |
| `services.prowlarr.apiKey` | Prowlarr API key (use existingSecret) | `""` |
| `services.bazarr.enabled` | Enable Bazarr backups | `true` |
| `services.bazarr.url` | Bazarr service URL | `"http://bazarr.media.svc.cluster.local:6767"` |
| `services.bazarr.apiKey` | Bazarr API key (use existingSecret) | `""` |
| `existingSecret` | Name of existing secret with API keys | `""` |
| `storage.storageClassName` | StorageClass for PVC | `"synology-nfs-storage"` |
| `storage.accessMode` | PVC access mode | `ReadWriteMany` |
| `storage.size` | PVC size | `10Gi` |
| `storage.existingPvc` | Use existing PVC | `""` |
| `storage.nfs.enabled` | Use direct NFS mount | `false` |
| `storage.nfs.server` | NFS server address | `""` |
| `storage.nfs.path` | NFS export path | `"/volume1/media/backup"` |
| `retention.enabled` | Enable automatic cleanup | `true` |
| `retention.days` | Keep backups for N days | `30` |
| `resources.limits.cpu` | CPU limit | `200m` |
| `resources.limits.memory` | Memory limit | `128Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `64Mi` |
| `successfulJobsHistoryLimit` | Keep N successful jobs | `3` |
| `failedJobsHistoryLimit` | Keep N failed jobs | `3` |
| `restartPolicy` | Job restart policy | `OnFailure` |

## License

This chart is part of the GXF Kubernetes infrastructure.

## Maintainers

- GXF Team

## Support

For issues and questions:

1. Check the troubleshooting section above
2. Review logs with `kubectl logs`
3. Open an issue in the repository

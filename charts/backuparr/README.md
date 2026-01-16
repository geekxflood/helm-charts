# Backuparr

Automated backup solution for *arr applications using their native APIs.

## Overview

Backuparr is a Kubernetes CronJob that:

1. **API Backups**: Triggers backup via Servarr API for Radarr, Sonarr, Prowlarr, Lidarr, Readarr
2. **Filesystem Backups**: Copies backup directory for apps like Bazarr
3. **Organizes**: Stores backups in `/{app}/{date}/{app}_{timestamp}.zip`
4. **Cleans up**: Removes backups older than retention period

## Supported Applications

| Application | Backup Method | API Version |
|-------------|---------------|-------------|
| Radarr      | API           | v3          |
| Sonarr      | API           | v3          |
| Prowlarr    | API           | v1          |
| Lidarr      | API           | v3          |
| Readarr     | API           | v3          |
| Bazarr      | Filesystem    | N/A         |

## Prerequisites

1. **API Keys Secret**: Create a secret with API keys for each app:

```bash
kubectl create secret generic backuparr-api-keys \
  --namespace=media \
  --from-literal=radarr=YOUR_RADARR_API_KEY \
  --from-literal=sonarr=YOUR_SONARR_API_KEY \
  --from-literal=prowlarr=YOUR_PROWLARR_API_KEY
```

2. **NFS Backup Directory**: Ensure `/volume1/media/backup` exists on your NAS

## Installation

### Via ArgoCD (Recommended)

Apply the ArgoCD Application:

```bash
kubectl apply -f argocd/apps/media/backuparr.yaml
```

### Via Helm

```bash
helm install backuparr ./charts/backuparr \
  --namespace media \
  --set existingSecret=backuparr-api-keys
```

## Configuration

### values.yaml

```yaml
# Schedule (cron format)
schedule: "0 3 * * *"  # 3 AM daily
timezone: "Europe/Zurich"

# Applications
apps:
  radarr:
    enabled: true
    url: "http://radarr.media.svc.cluster.local:7878"
    apiVersion: "v3"
  sonarr:
    enabled: true
    url: "http://sonarr.media.svc.cluster.local:8989"
    apiVersion: "v3"
  prowlarr:
    enabled: true
    url: "http://prowlarr.media.svc.cluster.local:9696"
    apiVersion: "v1"
  bazarr:
    enabled: true
    configPvc: "bazarr-config-iscsi-pvc"

# Storage
storage:
  nfs:
    server: "10.0.0.4"
    path: "/volume1/media/backup"

# Retention
retention:
  enabled: true
  days: 30
```

## Backup Structure

```
/volume1/media/backup/
├── radarr/
│   └── 2025-01-16/
│       └── radarr_20250116_030000.zip
├── sonarr/
│   └── 2025-01-16/
│       └── sonarr_20250116_030000.zip
├── prowlarr/
│   └── 2025-01-16/
│       └── prowlarr_20250116_030000.zip
└── bazarr/
    └── 2025-01-16/
        └── bazarr_20250116_030000.tar.gz
```

## Operations

### Manually Trigger Backup

```bash
kubectl create job --from=cronjob/backuparr backuparr-manual -n media
```

### View Backup Logs

```bash
kubectl logs -n media job/backuparr-manual
```

### Check Backup Status

```bash
kubectl get cronjobs -n media backuparr
kubectl get jobs -n media -l app.kubernetes.io/name=backuparr
```

## Restoring from Backup

### Radarr/Sonarr/Prowlarr

1. Stop the application
2. Copy the backup zip to the app's config directory
3. Use the app's System > Backup > Restore feature
4. Or extract manually to the config directory

### Bazarr

1. Stop Bazarr
2. Extract the tar.gz to the config directory:
   ```bash
   tar -xzf bazarr_20250116_030000.tar.gz -C /config/
   ```
3. Start Bazarr

## Troubleshooting

### No API Key Error

Ensure the secret exists and has the correct keys:

```bash
kubectl get secret backuparr-api-keys -n media -o yaml
```

### Backup Too Small

The app may not have created a backup yet. Check if backups exist in the app's UI.

### Connection Refused

Verify the service URL is correct:

```bash
kubectl get svc -n media
```

# Jellyfin PostgreSQL Database

PostgreSQL cluster for Jellyfin using CloudNativePG operator.

## Overview

This Helm chart deploys a highly available PostgreSQL cluster specifically configured for Jellyfin. It uses the CloudNativePG operator to manage the database lifecycle, including:

- Automated failover and self-healing
- Streaming replication with synchronous mode for zero data loss
- Rolling updates with minimal downtime
- Automated backups (when configured)
- Monitoring integration with Prometheus

## Prerequisites

- Kubernetes 1.24+
- CloudNativePG operator installed in the cluster
- StorageClass available (default: `synology-csi-iscsi-retain`)

## Installation

### 1. Install CloudNativePG Operator

The CloudNativePG operator must be installed before deploying this chart:

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update
helm upgrade --install cnpg \
  --namespace cnpg-system \
  --create-namespace \
  cnpg/cloudnative-pg
```

### 2. Deploy Jellyfin Database

Deploy via ArgoCD or Helm:

```bash
helm install jellyfin-database ./charts/jellyfin-database \
  --namespace database \
  --create-namespace
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cluster.instances` | Number of PostgreSQL instances | `3` |
| `cluster.storage.size` | Data storage size | `50Gi` |
| `cluster.storage.storageClass` | Storage class for data | `synology-csi-iscsi-retain` |
| `cluster.walStorage.enabled` | Enable dedicated WAL storage | `true` |
| `cluster.walStorage.size` | WAL storage size | `10Gi` |
| `highAvailability.synchronousReplication.enabled` | Enable sync replication | `true` |
| `monitoring.enabled` | Enable Prometheus metrics | `true` |
| `backup.enabled` | Enable backup configuration | `true` |

### High Availability

The cluster is configured with:
- **3 instances**: 1 primary + 2 replicas
- **Synchronous replication**: Zero data loss with `remote_apply` mode
- **Pod anti-affinity**: Instances spread across different nodes
- **Automated failover**: Automatic promotion of replicas on primary failure

### Storage

Two storage volumes per instance:
1. **Data volume** (`50Gi`): PostgreSQL data directory
2. **WAL volume** (`10Gi`): Write-Ahead Log for better I/O performance

### Performance Tuning

PostgreSQL is configured with optimized parameters:
- `max_connections: 200`
- `shared_buffers: 256MB`
- `effective_cache_size: 1GB`
- `work_mem: 2MB`

Adjust these values in `values.yaml` based on your workload.

## Usage

### Connection Information

The cluster creates three services:

1. **Read-Write Service** (`postgres-ha-rw`): Primary instance for writes
2. **Read-Only Service** (`postgres-ha-ro`): Load-balanced reads across replicas
3. **Any Instance Service** (`postgres-ha-r`): Any available instance

### Get Credentials

```bash
# Application user password
kubectl get secret postgres-ha-app-user -n database \
  -o jsonpath='{.data.password}' | base64 -d

# Superuser password
kubectl get secret postgres-ha-superuser -n database \
  -o jsonpath='{.data.password}' | base64 -d
```

### Connection String

From within the Kubernetes cluster:

```
postgresql://jellyfin:<password>@postgres-ha-rw.database.svc.cluster.local:5432/jellyfin
```

### Test Connection

```bash
kubectl run -it --rm psql --image=postgres:16-alpine --restart=Never -- \
  psql -h postgres-ha-rw.database.svc.cluster.local -U jellyfin -d jellyfin
```

## Monitoring

### Check Cluster Status

```bash
# Overall status
kubectl get cluster postgres-ha -n database

# Detailed information
kubectl describe cluster postgres-ha -n database

# Pod status
kubectl get pods -n database -l cnpg.io/cluster=postgres-ha
```

### Prometheus Metrics

When `monitoring.enabled: true`, the cluster exposes metrics via PodMonitor:

```bash
kubectl get podmonitor postgres-ha -n database
```

Metrics are available at: `http://<pod-ip>:9187/metrics`

## Backup and Recovery

### Configure Backups

To enable automated backups to S3-compatible storage:

```yaml
backup:
  enabled: true
  barmanObjectStore:
    enabled: true
    destinationPath: s3://my-bucket/jellyfin-backups
    s3Credentials:
      secretName: s3-credentials
```

Create S3 credentials secret:

```bash
kubectl create secret generic s3-credentials -n database \
  --from-literal=ACCESS_KEY_ID=your-access-key \
  --from-literal=SECRET_ACCESS_KEY=your-secret-key
```

### Manual Backup

```bash
kubectl cnpg backup postgres-ha -n database
```

### List Backups

```bash
kubectl get backups -n database
```

## Maintenance

### Scaling Replicas

Edit `values.yaml` and update `cluster.instances`:

```yaml
cluster:
  instances: 5  # Scale to 5 instances
```

Then upgrade the release:

```bash
helm upgrade jellyfin-database ./charts/jellyfin-database -n database
```

### Rolling Updates

PostgreSQL version updates are handled automatically:

1. Update `cluster.imageName` in `values.yaml`
2. Upgrade the Helm release
3. CloudNativePG performs rolling update with minimal downtime

### Switchover (Planned Failover)

```bash
kubectl cnpg promote postgres-ha-2 -n database
```

## Troubleshooting

### Check Cluster Events

```bash
kubectl get events -n database --field-selector involvedObject.name=postgres-ha
```

### View Logs

```bash
# Primary instance
kubectl logs -n database -l cnpg.io/cluster=postgres-ha,role=primary -f

# All instances
kubectl logs -n database -l cnpg.io/cluster=postgres-ha --all-containers -f
```

### Common Issues

#### Pods Stuck in Pending

Check PVC status:
```bash
kubectl get pvc -n database
```

Verify StorageClass exists:
```bash
kubectl get storageclass synology-csi-iscsi-retain
```

#### Synchronous Replication Blocking Writes

If write performance is impacted, consider switching to asynchronous:

```yaml
highAvailability:
  synchronousReplication:
    enabled: false
```

#### Connection Refused

Verify services are running:
```bash
kubectl get svc -n database
kubectl get endpoints postgres-ha-rw -n database
```

## OpenBao Integration (Future)

When OpenBao is configured, enable dynamic credential management:

```yaml
openbao:
  enabled: true
  path: database/creds/jellyfin-role
  role: jellyfin-role
  renewalThreshold: 3600
```

This will automatically:
1. Request credentials from OpenBao on startup
2. Renew credentials before expiration
3. Handle credential rotation seamlessly

## Resources

- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)
- [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/16/)
- [Jellyfin External Database Setup](https://jellyfin.org/docs/general/administration/configuration.html#database)

## License

This chart is provided as-is for use with the GXF Kubernetes cluster.

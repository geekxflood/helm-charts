# PostgreSQL HA Helm Chart

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 16](https://img.shields.io/badge/AppVersion-16-informational?style=flat-square)

A Helm chart that deploys a highly-available PostgreSQL cluster as a [CloudNativePG](https://cloudnative-pg.io/) `Cluster` Custom Resource. The chart does **not** run PostgreSQL pods directly — it renders a single `postgresql.cnpg.io/v1` `Cluster` object, and the CloudNativePG operator reconciles pods, services, secrets, PVCs, failover, backups, and rolling updates.

This is the recommended PostgreSQL backend for stateful self-hosted services in this repo (Keycloak, Jellyfin, Sonarr/Radarr metadata, etc.). Pair with [database-provisioner](../database-provisioner) to bootstrap per-app databases and roles from `Database` CRDs.

## Features

- Provisions a CloudNativePG `Cluster` CR with N instances (1 primary + N-1 replicas)
- Streaming replication, with optional **synchronous** replication (`remote_apply`) for zero data-loss writes
- Separate WAL PVC for IO isolation (`cluster.walStorage.enabled`)
- Automated failover, self-healing, rolling minor version upgrades — all delegated to the operator
- Tuned PostgreSQL parameters (memory, parallelism, WAL) overridable in `postgresql.parameters`
- Optional Barman Cloud backups to S3-compatible storage (Garage, AWS S3, …)
- Optional `PodMonitor` for the Prometheus Operator
- Pod anti-affinity by hostname (preferred or required)
- Three CloudNativePG-managed services: `<cluster>-rw`, `<cluster>-ro`, `<cluster>-r`
- Future-ready OpenBao block for dynamic role credentials

## Prerequisites

- Kubernetes 1.24+
- Helm 3.0+
- [CloudNativePG operator](https://cloudnative-pg.io/documentation/current/installation_upgrade/) **must be installed in the cluster** before this chart is applied. Install via its own chart:

  ```bash
  helm repo add cnpg https://cloudnative-pg.github.io/charts
  helm upgrade --install cnpg --namespace cnpg-system --create-namespace cnpg/cloudnative-pg
  ```

- A `StorageClass` that supports `ReadWriteOnce` PVCs (data and optionally WAL)
- For backups: an S3-compatible bucket and a `Secret` with `ACCESS_KEY_ID` / `SECRET_ACCESS_KEY` keys
- For monitoring: the Prometheus Operator (`PodMonitor` CRD)

## Installation

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm install postgres-ha geekxflood/postgres-ha -n database --create-namespace
helm install postgres-ha geekxflood/postgres-ha -n database --create-namespace -f values.yaml
```

Verify the cluster came up:

```bash
kubectl get cluster postgres-ha -n database
kubectl get pods -n database -l cnpg.io/cluster=postgres-ha
```

## Configuration

### Cluster

| Parameter                                                             | Description                          | Default                                  |
| --------------------------------------------------------------------- | ------------------------------------ | ---------------------------------------- |
| `cluster.name`                                                        | Name of the `Cluster` CR             | `postgres-ha`                            |
| `cluster.instances`                                                   | Total instances (primary + replicas) | `3`                                      |
| `cluster.imageName`                                                   | CNPG-flavoured Postgres image        | `ghcr.io/cloudnative-pg/postgresql:16.2` |
| `cluster.storage.size`                                                | Data PVC size                        | `50Gi`                                   |
| `cluster.storage.storageClass`                                        | Data StorageClass                    | `""` (cluster default)                   |
| `cluster.walStorage.enabled`                                          | Use a dedicated WAL PVC              | `false`                                  |
| `cluster.walStorage.size`                                             | WAL PVC size                         | `10Gi`                                   |
| `cluster.walStorage.storageClass`                                     | WAL StorageClass                     | `""`                                     |
| `cluster.bootstrap.initdb.database`                                   | Initial DB name                      | `app`                                    |
| `cluster.bootstrap.initdb.owner`                                      | Initial DB owner role                | `app`                                    |
| `cluster.bootstrap.initdb.localeCollate` / `localeCType` / `encoding` | initdb locale settings               | `en_US.UTF-8` / `en_US.UTF-8` / `UTF8`   |

### High availability

| Parameter                                         | Description                            | Default        |
| ------------------------------------------------- | -------------------------------------- | -------------- |
| `highAvailability.enabled`                        | Master HA toggle                       | `true`         |
| `highAvailability.synchronousReplication.enabled` | Use synchronous replication            | `false`        |
| `highAvailability.synchronousReplication.method`  | `remote_apply` / `remote_write` / `on` | `remote_apply` |
| `highAvailability.synchronousReplication.number`  | `min/maxSyncReplicas`                  | `1`            |
| `affinity.enablePodAntiAffinity`                  | Anti-affinity across nodes             | `true`         |
| `affinity.podAntiAffinityType`                    | `preferred` or `required`              | `preferred`    |

When `synchronousReplication.enabled: true`, the chart sets both `minSyncReplicas` and `maxSyncReplicas` on the `Cluster` spec — writes will block if fewer than `number` replicas can acknowledge.

### PostgreSQL parameters

`postgresql.parameters` is a flat map applied verbatim to the cluster. Defaults are tuned for a ~2 GiB-limit Postgres pod:

| Parameter                                      | Default        |
| ---------------------------------------------- | -------------- |
| `max_connections`                              | `200`          |
| `shared_buffers`                               | `256MB`        |
| `effective_cache_size`                         | `1GB`          |
| `work_mem`                                     | `2MB`          |
| `maintenance_work_mem`                         | `64MB`         |
| `wal_buffers`                                  | `16MB`         |
| `min_wal_size` / `max_wal_size`                | `1GB` / `4GB`  |
| `random_page_cost`                             | `1.1` (SSD)    |
| `log_statement` / `log_min_duration_statement` | `ddl` / `1000` |

Override per-workload — e.g. bump `work_mem` for analytics, raise `max_connections` for many small services.

### Backups (Barman Cloud / S3)

| Parameter                                           | Description                                       | Default |
| --------------------------------------------------- | ------------------------------------------------- | ------- |
| `backup.enabled`                                    | Include the `backup` block in the `Cluster` CR    | `false` |
| `backup.barmanObjectStore.enabled`                  | Enable S3-compatible object store backup          | `false` |
| `backup.barmanObjectStore.destinationPath`          | `s3://bucket/prefix` URL                          | `""`    |
| `backup.barmanObjectStore.s3Credentials.secretName` | Secret with `ACCESS_KEY_ID` / `SECRET_ACCESS_KEY` | `""`    |
| `backup.retentionPolicy`                            | Retention (e.g. `30d`)                            | `30d`   |

The chart only configures the `Cluster` — backups are triggered by `Backup` / `ScheduledBackup` CRs you create separately (`kubectl cnpg backup …`).

### Monitoring

| Parameter                       | Description                              | Default |
| ------------------------------- | ---------------------------------------- | ------- |
| `monitoring.enabled`            | Enable monitoring block on the `Cluster` | `false` |
| `monitoring.podMonitor.enabled` | Render the `PodMonitor` via CNPG         | `false` |

Metrics are exposed at `:9187/metrics` per pod.

### Services & secrets

| Parameter                     | Description                                              | Default       |
| ----------------------------- | -------------------------------------------------------- | ------------- |
| `service.type`                | Service type                                             | `ClusterIP`   |
| `service.readService.enabled` | Expose the `-ro` read-only service                       | `true`        |
| `superuserSecret.name`        | Name of the superuser `Secret` (CNPG-managed when empty) | `""`          |
| `managed.roles`               | List of CNPG-managed extra roles                         | `[]`          |
| `maintenanceWindow.enabled`   | Define a maintenance window                              | `false`       |
| `maintenanceWindow.schedule`  | Cron schedule                                            | `"0 2 * * 0"` |

CNPG creates three Kubernetes services by default:

| Service        | Purpose                                   |
| -------------- | ----------------------------------------- |
| `<cluster>-rw` | Read/write — always points to the primary |
| `<cluster>-ro` | Read-only — load-balanced across replicas |
| `<cluster>-r`  | Any instance — primary or replicas        |

### OpenBao (future)

| Parameter                  | Description                                        | Default |
| -------------------------- | -------------------------------------------------- | ------- |
| `openbao.enabled`          | Reserved for dynamic role credentials              | `false` |
| `openbao.path`             | OpenBao path (e.g. `database/creds/keycloak-role`) | `""`    |
| `openbao.role`             | OpenBao role                                       | `""`    |
| `openbao.renewalThreshold` | Renewal threshold (seconds)                        | `3600`  |

## Examples

### Production HA cluster with WAL volume, sync replication, backups, and monitoring

```yaml
cluster:
  name: postgres-ha
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:16.2
  storage:
    size: 200Gi
    storageClass: bulk-ssd
  walStorage:
    enabled: true
    size: 50Gi
    storageClass: fast-nvme

highAvailability:
  synchronousReplication:
    enabled: true
    method: remote_apply
    number: 1

backup:
  enabled: true
  barmanObjectStore:
    enabled: true
    destinationPath: s3://gxf-postgres-backups/postgres-ha
    s3Credentials:
      secretName: garage-s3-credentials
  retentionPolicy: "30d"

monitoring:
  enabled: true
  podMonitor:
    enabled: true

affinity:
  enablePodAntiAffinity: true
  podAntiAffinityType: required

resources:
  requests:
    memory: 2Gi
    cpu: "1"
  limits:
    memory: 8Gi
    cpu: "4"

postgresql:
  parameters:
    shared_buffers: "2GB"
    effective_cache_size: "6GB"
    work_mem: "16MB"
    max_connections: "300"
```

Create the S3 credentials secret (when using [Garage](../garage) as the backup target):

```bash
kubectl -n database create secret generic garage-s3-credentials \
  --from-literal=ACCESS_KEY_ID=<garage-access-key> \
  --from-literal=SECRET_ACCESS_KEY=<garage-secret-key>
```

### Minimal dev cluster (single primary, no backups)

```yaml
cluster:
  name: postgres-dev
  instances: 1
  storage:
    size: 10Gi

highAvailability:
  enabled: false

resources:
  requests:
    memory: 256Mi
    cpu: 100m
  limits:
    memory: 1Gi
    cpu: 500m
```

## Persistence

Each instance has up to two PVCs: a **data** PVC (`cluster.storage.size`) and an optional **WAL** PVC (`cluster.walStorage.size`). PVCs are managed by the CloudNativePG operator and survive Helm uninstall — clean them up manually if you really want them gone:

```bash
kubectl delete pvc -n database -l cnpg.io/cluster=postgres-ha
```

WAL volumes pay off when write throughput is sustained or when the storage backend has tail-latency under bursts — keep them on **fast** storage (NVMe) even when data sits on cheaper storage.

## Integration notes

- **Apps consume the cluster via the `<cluster>-rw` service.** Connection string format:

  ```txt
  postgresql://<user>:<pass>@postgres-ha-rw.database.svc.cluster.local:5432/<db>
  ```

- **Per-app databases** are best created via the [database-provisioner](../database-provisioner) chart: an app creates a `Database` CR referencing this cluster, and the provisioner CronJob creates the database, role, and per-app `Secret`.
- **Credentials**: the bootstrap user (`app` by default) gets a CNPG-managed `Secret` named `<cluster>-app`. The superuser secret is `<cluster>-superuser`.
- **Failover** is automatic — applications must reconnect on transient errors. The `-rw` Service endpoint is updated within seconds of failover.
- **Backups** require a separate `ScheduledBackup` / `Backup` CR — this chart only enables the `Cluster.spec.backup` configuration block.

## Upgrading

- **Patch versions of PostgreSQL** are rolled out by the operator via in-place restart of each replica, then a switchover. Update `cluster.imageName` to a new patch tag (e.g. `16.2` → `16.3`) and `helm upgrade`.
- **Major version upgrades** (16 → 17) require an offline procedure (`kubectl cnpg pg_basebackup` / `pg_upgrade`) — do not just bump `imageName` across majors.
- **Scaling**: change `cluster.instances` and `helm upgrade`. The operator adds/removes replicas with rolling reconfiguration.
- **Synchronous replication** activation can cause writes to block immediately if a replica isn't healthy — verify replica health before enabling on a running cluster.

## Support

- CloudNativePG docs: <https://cloudnative-pg.io/documentation/>
- PostgreSQL docs: <https://www.postgresql.org/docs/16/>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

- Chart: Apache License 2.0
- PostgreSQL: [PostgreSQL License](https://www.postgresql.org/about/licence/)
- CloudNativePG: [Apache License 2.0](https://github.com/cloudnative-pg/cloudnative-pg/blob/main/LICENSE)

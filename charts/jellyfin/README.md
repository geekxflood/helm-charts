# Jellyfin Helm Chart

![Version: 0.10.0](https://img.shields.io/badge/Version-0.10.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 10.11.6](https://img.shields.io/badge/AppVersion-10.11.6-informational?style=flat-square)

A Helm chart for deploying Jellyfin on Kubernetes.

## Overview

[Jellyfin](https://jellyfin.org/) is a Free Software Media System that puts you in control of managing and streaming your media. It is an alternative to the proprietary Emby and Plex, to provide media from a dedicated server to end-user devices via multiple apps.

This Helm chart deploys Jellyfin on a Kubernetes cluster using the [LinuxServer.io Jellyfin image](https://hub.docker.com/r/linuxserver/jellyfin).

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Persistent storage for media and configuration (recommended)

## Installation

### Add the Helm repository

```bash
helm repo add your-repo https://your-repo-url
helm repo update
```

### Install the chart

```bash
helm install jellyfin your-repo/jellyfin
```

### Install with custom values

```bash
helm install jellyfin your-repo/jellyfin -f values.yaml
```

## Configuration

The following table lists the configurable parameters of the Jellyfin chart and their default values.

### Global Parameters

| Parameter      | Description                         | Default |
| -------------- | ----------------------------------- | ------- |
| `enabled`      | Enable/disable the chart deployment | `false` |
| `replicaCount` | Number of Jellyfin replicas         | `1`     |

### Image Parameters

| Parameter          | Description               | Default                |
| ------------------ | ------------------------- | ---------------------- |
| `image.repository` | Jellyfin image repository | `linuxserver/jellyfin` |
| `image.pullPolicy` | Image pull policy         | `IfNotPresent`         |
| `image.tag`        | Image tag                 | `"10.11.6"`            |
| `imagePullSecrets` | Image pull secrets        | `[]`                   |

### Service Account Parameters

| Parameter                    | Description                     | Default |
| ---------------------------- | ------------------------------- | ------- |
| `serviceAccount.create`      | Create service account          | `true`  |
| `serviceAccount.automount`   | Automount service account token | `true`  |
| `serviceAccount.annotations` | Service account annotations     | `{}`    |
| `serviceAccount.name`        | Service account name            | `""`    |

### Pod Parameters

| Parameter            | Description                | Default |
| -------------------- | -------------------------- | ------- |
| `nameOverride`       | Override chart name        | `""`    |
| `fullnameOverride`   | Override full chart name   | `""`    |
| `podAnnotations`     | Pod annotations            | `{}`    |
| `podLabels`          | Pod labels                 | `{}`    |
| `podSecurityContext` | Pod security context       | `{}`    |
| `securityContext`    | Container security context | `{}`    |

### GPU Parameters

| Parameter           | Description                       | Default  |
| ------------------- | --------------------------------- | -------- |
| `gpu.enabled`       | Enable GPU support for transcoding | `false`  |
| `gpu.runtimeClass`  | Runtime class for GPU             | `nvidia` |
| `gpu.count`         | Number of GPUs to allocate        | `1`      |

### Environment Variables

| Parameter | Description                                 | Default |
| --------- | ------------------------------------------- | ------- |
| `env`     | Environment variables array                 | `[]`    |
| `envFrom` | Environment variables from ConfigMap/Secret | `[]`    |

### Service Parameters

| Parameter      | Description  | Default     |
| -------------- | ------------ | ----------- |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `8096`      |

### Ingress Parameters

| Parameter             | Description                 | Default         |
| --------------------- | --------------------------- | --------------- |
| `ingress.enabled`     | Enable ingress              | `false`         |
| `ingress.className`   | Ingress class name          | `""`            |
| `ingress.annotations` | Ingress annotations         | `{}`            |
| `ingress.hosts`       | Ingress hosts configuration | See values.yaml |
| `ingress.tls`         | Ingress TLS configuration   | `[]`            |

### Cloudflare Tunnel Parameters

| Parameter            | Description              | Default |
| -------------------- | ------------------------ | ------- |
| `cfTunnel.enabled`   | Enable Cloudflare Tunnel | `false` |
| `cfTunnel.tunnelRef` | Tunnel reference         | `{}`    |
| `cfTunnel.subjects`  | Tunnel subjects          | `[]`    |

### Resource Management

| Parameter   | Description                  | Default |
| ----------- | ---------------------------- | ------- |
| `resources` | Resource requests and limits | `{}`    |

### OpenBao (Vault) Integration

| Parameter                              | Description                          | Default                                  |
| -------------------------------------- | ------------------------------------ | ---------------------------------------- |
| `openbao.enabled`                      | Enable OpenBao integration           | `false`                                  |
| `openbao.vaultConnectionRef`           | VaultConnection reference            | `vault-secrets-operator-system/default`  |
| `openbao.vaultAuth.create`             | Create VaultAuth resource            | `true`                                   |
| `openbao.vaultAuth.mount`              | Kubernetes auth method mount         | `kubernetes`                             |
| `openbao.vaultAuth.role`               | OpenBao role name                    | `media`                                  |
| `openbao.vaultAuth.tokenExpirationSeconds` | Token expiration                 | `600`                                    |
| `openbao.staticSecret.enabled`         | Enable static secret from KV store   | `false`                                  |
| `openbao.staticSecret.mount`           | KV v2 mount path                     | `secret`                                 |
| `openbao.staticSecret.path`            | Path to secret within mount          | `""`                                     |
| `openbao.staticSecret.secretName`      | Kubernetes secret name to create     | `""`                                     |
| `openbao.staticSecret.refreshAfter`    | Refresh interval                     | `1h`                                     |

### SSO Plugin Configuration

| Parameter           | Description                              | Default     |
| ------------------- | ---------------------------------------- | ----------- |
| `sso.enabled`       | Enable SSO configuration via init container | `false`  |
| `sso.providerName`  | OIDC Provider name                       | `Discord`   |
| `sso.oidcEndpoint`  | OIDC endpoint URL                        | `""`        |
| `sso.clientId`      | OIDC client ID                           | `""`        |
| `sso.clientSecret`  | OIDC client secret                       | `""`        |
| `sso.canonicalUrl`  | Canonical URL for Jellyfin               | `""`        |
| `sso.disablePAR`    | Disable Pushed Authorization Request     | `true`      |
| `sso.uid`           | UID for file ownership                   | `1000`      |
| `sso.gid`           | GID for file ownership                   | `100`       |

### Database Optimization Parameters

| Parameter                                   | Description                                    | Default              |
| ------------------------------------------- | ---------------------------------------------- | -------------------- |
| `optimization.enabled`                      | Enable database optimization                   | `false`              |
| `optimization.sqlite.enabled`               | Enable SQLite optimization init container      | `true`               |
| `optimization.sqlite.runOptimize`           | Run PRAGMA optimize and ANALYZE                | `true`               |
| `optimization.sqlite.enableWAL`             | Ensure WAL journal mode is enabled             | `true`               |
| `optimization.sqlite.runReindex`            | Run REINDEX to rebuild indexes                 | `false`              |
| `optimization.sqlite.runVacuum`             | Run VACUUM to compact database                 | `false`              |
| `optimization.sqlite.enableAutoVacuum`      | Enable incremental auto-vacuum mode            | `true`               |
| `optimization.sqlite.runIncrementalVacuum`  | Run incremental vacuum (reclaim ~1000 pages)   | `true`               |
| `optimization.sqlite.truncateWAL`           | Checkpoint and truncate WAL file               | `true`               |
| `optimization.sqlite.backupRetention`       | Number of backups to retain                    | `3`                  |
| `optimization.sqlite.configPath`            | Path to config volume mount                    | `/config`            |
| `optimization.sqlite.dbPath`                | Database path relative to config               | `data/data/jellyfin.db` |
| `optimization.sqlite.backupDir`             | Backup directory relative to configPath        | `data/backups/sqlite-optimization` |
| `optimization.sqlite.image.repository`      | Init container image                           | `alpine`             |
| `optimization.sqlite.image.tag`             | Init container image tag                       | `3.21`               |
| `optimization.sqlite.resources`             | Init container resources                       | See values.yaml      |

### Autoscaling Parameters

| Parameter                                       | Description                      | Default |
| ----------------------------------------------- | -------------------------------- | ------- |
| `autoscaling.enabled`                           | Enable horizontal pod autoscaler | `false` |
| `autoscaling.minReplicas`                       | Minimum replicas                 | `1`     |
| `autoscaling.maxReplicas`                       | Maximum replicas                 | `100`   |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU utilization           | `80`    |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization        | `80`    |

### Vertical Pod Autoscaler Parameters

| Parameter        | Description                      | Default |
| ---------------- | -------------------------------- | ------- |
| `vpa.enabled`    | Enable vertical pod autoscaler   | `true`  |
| `vpa.updateMode` | VPA update mode                  | `Auto`  |

### Storage Parameters

| Parameter      | Description              | Default |
| -------------- | ------------------------ | ------- |
| `volumes`      | Additional volumes       | `[]`    |
| `volumeMounts` | Additional volume mounts | `[]`    |

### Node Selection Parameters

| Parameter      | Description    | Default |
| -------------- | -------------- | ------- |
| `nodeSelector` | Node selector  | `{}`    |
| `tolerations`  | Tolerations    | `[]`    |
| `affinity`     | Affinity rules | `{}`    |

## Examples

### Basic Installation with Ingress

```yaml
enabled: true

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: jellyfin.example.com
      paths:
        - path: /
          pathType: Prefix

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: jellyfin-config
  - name: media
    persistentVolumeClaim:
      claimName: jellyfin-media

volumeMounts:
  - name: config
    mountPath: /config
  - name: media
    mountPath: /media
```

### Installation with GPU Support

```yaml
enabled: true

gpu:
  enabled: true
  runtimeClass: nvidia
  count: 1

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: jellyfin-config
  - name: media
    persistentVolumeClaim:
      claimName: jellyfin-media

volumeMounts:
  - name: config
    mountPath: /config
  - name: media
    mountPath: /media
```

### Installation with Database Optimization

This feature runs SQLite optimizations via an init container before Jellyfin starts. It creates a backup of the database before running optimizations and restores it if any operation fails.

```yaml
enabled: true

optimization:
  enabled: true
  sqlite:
    enabled: true
    runOptimize: true    # Run PRAGMA optimize and ANALYZE
    enableWAL: true      # Ensure WAL mode (recommended)
    runReindex: false    # Rebuild indexes (run occasionally)
    runVacuum: false     # Compact database (slow on large DBs)
    backupRetention: 3   # Keep last 3 backups

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: jellyfin-config

volumeMounts:
  - name: config
    mountPath: /config
```

#### Optimization Options Explained

| Option | Description | When to Use |
| ------ | ----------- | ----------- |
| `runOptimize` | Runs `PRAGMA optimize` and `ANALYZE` to update query planner statistics | Always recommended, safe for every restart |
| `enableWAL` | Ensures WAL (Write-Ahead Logging) mode for concurrent reads/writes | Always recommended, already Jellyfin default |
| `enableAutoVacuum` | Sets `auto_vacuum=INCREMENTAL` for gradual space reclamation | Always recommended, persists in database |
| `runIncrementalVacuum` | Reclaims ~1000 free pages without full VACUUM overhead | Always recommended, lightweight operation |
| `truncateWAL` | Checkpoints and truncates WAL file to reclaim disk space | Always recommended, prevents WAL file growth |
| `runReindex` | Rebuilds all indexes to fix fragmentation | Run periodically or after large library changes |
| `runVacuum` | Compacts database and defragments free space | Run occasionally, can be slow on large databases (700MB+) |

#### Backup and Recovery Behavior

- Backups are stored in `{configPath}/{backupDir}` (default: `/config/data/backups/sqlite-optimization`)
- Each backup is timestamped (e.g., `jellyfin_20240115_143022.db`)
- WAL and SHM files are also backed up if present
- Old backups are automatically cleaned up based on `backupRetention`
- If any optimization fails, the backup is automatically restored
- **Important**: The init container always exits successfully (exit 0) after restore, ensuring Jellyfin starts with the original database

### Installation with OpenBao Secrets

```yaml
enabled: true

openbao:
  enabled: true
  vaultConnectionRef: "vault-secrets-operator-system/default"
  vaultAuth:
    create: true
    mount: "kubernetes"
    role: "media"
  staticSecret:
    enabled: true
    mount: "secret"
    path: "media/jellyfin/credentials"

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: jellyfin-config

volumeMounts:
  - name: config
    mountPath: /config
```

## Persistence

Jellyfin requires persistent storage for:

1. **Configuration data** (`/config`): Stores server configuration, metadata, and database
2. **Media files** (`/media`): Your media library (videos, music, photos)

It is strongly recommended to use PersistentVolumeClaims for both directories in production environments.

## Upgrading

### To 0.10.0

- Added database optimization feature with init container
- Updated appVersion to 10.11.6
- Added `optimization` configuration section

### To 0.9.0

- Added OpenBao (Vault) integration for secrets management
- Added SSO plugin configuration support

### To 0.1.0

This is the initial release of the chart.

## Uninstallation

```bash
helm uninstall jellyfin
```

## Support

For issues and questions:

- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [Chart Repository Issues](https://github.com/your-repo/issues)

## License

This Helm chart is licensed under the Apache License 2.0.

Jellyfin is licensed under the GNU GPL v2. See the [Jellyfin License](https://github.com/jellyfin/jellyfin/blob/master/LICENSE) for details.

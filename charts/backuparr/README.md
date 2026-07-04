# Backuparr Helm Chart

![Version: 1.2.1](https://img.shields.io/badge/Version-1.2.1-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.2.0](https://img.shields.io/badge/AppVersion-1.2.0-informational?style=flat-square)

Backuparr is an automated, schedule-driven backup solution for the *arr stack and friends. It runs as a Kubernetes `CronJob` that — for each enabled application — either triggers the app's **native backup API** (Radarr, Sonarr, Prowlarr, Lidarr, Readarr, SABnzbd, Overseerr/Jellyseerr, Audiobookshelf) or performs a **`kubectl exec`-driven filesystem snapshot** (Bazarr, Jellyfin, Tdarr, Kapowarr, LazyLibrarian, Wizarr, Tunarr). Backups land on a single NFS-backed PVC with configurable retention.

## Overview

The *arr ecosystem has no shared backup story. Each app has its own quirks: Servarr apps trigger backups via `/api/v3/command` but do not expose a download endpoint, so the backup file must be retrieved from the config volume; Bazarr stores backups inside its own config dir; Wizarr is a SQLite database with no API. Backuparr handles all of this in a single CronJob:

1. The job pod boots an Alpine image and installs `bash`, `curl`, `jq`, and (when filesystem backups are enabled) `kubectl`.
2. A bundled shell script (`/scripts/backup.sh`, mounted from a ConfigMap) walks the enabled apps.
3. API-driven apps get a backup triggered and verified via HTTP.
4. Filesystem-driven apps are either backed up via `kubectl exec` into a running pod (Bazarr) or by mounting the target app's config PVC read-only into the backup pod (Jellyfin, Tdarr, Kapowarr, LazyLibrarian, Wizarr, Tunarr).
5. All artifacts are tar/gz'd and written to `/backup` on the NFS-backed PVC, with optional day-based retention.

API keys are sourced from a single Kubernetes Secret (`existingSecret`) whose keys match the app names.

## Features

- **CronJob runtime** with `concurrencyPolicy: Forbid`, configurable schedule, timezone, and job history limits.
- **Native API backups** for Servarr apps (Radarr, Sonarr, Prowlarr, Lidarr, Readarr) plus SABnzbd, Overseerr/Jellyseerr, and Audiobookshelf.
- **Filesystem backups** for Bazarr (via `kubectl exec`) and Jellyfin / Tdarr / Kapowarr / LazyLibrarian / Wizarr / Tunarr (via mounted config PVCs).
- **Automatic RBAC** — when any filesystem app is enabled, the chart generates a `Role` granting `get`/`list` on `pods` and `create` on `pods/exec`, plus a matching `RoleBinding`. You do not have to set `rbac.create: true` explicitly for this; the template detects it.
- **NFS-backed PV/PVC** built into the chart (`storage.nfs.server`, `storage.nfs.path`) — shared across runs and across apps.
- **Retention** — purges backups older than `retention.days` (when `retention.enabled: true`).
- **Secret-driven API keys** — one `existingSecret` holds all keys, looked up via `secretKeyRef` with `optional: true` so missing keys skip that app gracefully.

## Prerequisites

- Kubernetes 1.21+ (CronJob v1)
- Helm 3.0+
- An NFS server reachable from cluster nodes (or substitute by editing `templates/pv.yaml` for a different backend)
- For each Servarr/API app: its in-cluster URL and an API key
- For filesystem apps: a running pod (Bazarr) or a config PVC (Jellyfin, Tdarr, Kapowarr, LazyLibrarian, Wizarr, Tunarr) accessible from the backup pod

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Create the API-key Secret

```bash
kubectl create secret generic backuparr-keys \
  --from-literal=radarr=YOUR_RADARR_KEY \
  --from-literal=sonarr=YOUR_SONARR_KEY \
  --from-literal=prowlarr=YOUR_PROWLARR_KEY \
  --from-literal=sabnzbd=YOUR_SABNZBD_KEY \
  --from-literal=seerr=YOUR_OVERSEERR_KEY
```

Only include keys for the apps you enable. Missing keys cause the script to skip that app — they will not fail the job.

### Install

```bash
helm install backuparr geekxflood/backuparr -f values.yaml
```

## Configuration

### Schedule & Image

| Parameter          | Description                                        | Default        |
| ------------------ | -------------------------------------------------- | -------------- |
| `schedule`         | CronJob schedule (UTC unless `timezone` overrides) | `0 3 * * *`    |
| `timezone`         | `spec.timeZone` for the CronJob                    | `UTC`          |
| `image.repository` | Base image (the chart installs tooling on top)     | `alpine`       |
| `image.tag`        | Image tag                                          | `3.23`         |
| `image.pullPolicy` | Image pull policy                                  | `IfNotPresent` |

### Servarr API apps

Each app block has the same shape: `enabled`, `url`, `apiVersion`. The API key comes from `existingSecret` (key = app name, lowercase).

| Parameter                  | Description                         | Default |
| -------------------------- | ----------------------------------- | ------- |
| `apps.radarr.enabled`      | Back up Radarr                      | `false` |
| `apps.radarr.url`          | Radarr base URL (no trailing slash) | `""`    |
| `apps.radarr.apiVersion`   | Radarr API version                  | `v3`    |
| `apps.sonarr.enabled`      | Back up Sonarr                      | `false` |
| `apps.sonarr.url`          | Sonarr base URL                     | `""`    |
| `apps.sonarr.apiVersion`   | Sonarr API version                  | `v3`    |
| `apps.prowlarr.enabled`    | Back up Prowlarr                    | `false` |
| `apps.prowlarr.url`        | Prowlarr base URL                   | `""`    |
| `apps.prowlarr.apiVersion` | Prowlarr API version                | `v1`    |
| `apps.lidarr.enabled`      | Back up Lidarr                      | `false` |
| `apps.lidarr.url`          | Lidarr base URL                     | `""`    |
| `apps.lidarr.apiVersion`   | Lidarr API version                  | `v3`    |
| `apps.readarr.enabled`     | Back up Readarr                     | `false` |
| `apps.readarr.url`         | Readarr base URL                    | `""`    |
| `apps.readarr.apiVersion`  | Readarr API version                 | `v3`    |

### Other API-driven apps

| Parameter                     | Description                     | Default |
| ----------------------------- | ------------------------------- | ------- |
| `apps.sabnzbd.enabled`        | Back up SABnzbd config          | `false` |
| `apps.sabnzbd.url`            | SABnzbd base URL                | `""`    |
| `apps.seerr.enabled`          | Back up Overseerr / Jellyseerr  | `false` |
| `apps.seerr.url`              | Overseerr / Jellyseerr base URL | `""`    |
| `apps.audiobookshelf.enabled` | Back up Audiobookshelf          | `false` |
| `apps.audiobookshelf.url`     | Audiobookshelf base URL         | `""`    |

### Filesystem apps (require PVC access or kubectl exec)

| Parameter                      | Description                                                             | Default |
| ------------------------------ | ----------------------------------------------------------------------- | ------- |
| `apps.bazarr.enabled`          | Back up Bazarr (via `kubectl exec` into its pod)                        | `false` |
| `apps.bazarr.configPvc`        | (Documented for reference; Bazarr is exec-driven, not PVC-mounted here) | `""`    |
| `apps.jellyfin.enabled`        | Back up Jellyfin config PVC                                             | `false` |
| `apps.jellyfin.configPvc`      | Name of Jellyfin's config PVC (mounted read-only at `/config/jellyfin`) | `""`    |
| `apps.tdarr.enabled`           | Back up Tdarr config PVC                                                | `false` |
| `apps.tdarr.configPvc`         | Name of Tdarr's config PVC                                              | `""`    |
| `apps.kapowarr.enabled`        | Back up Kapowarr config PVC                                             | `false` |
| `apps.kapowarr.configPvc`      | Name of Kapowarr's config PVC                                           | `""`    |
| `apps.lazylibrarian.enabled`   | Back up LazyLibrarian config PVC                                        | `false` |
| `apps.lazylibrarian.configPvc` | Name of LazyLibrarian's config PVC                                      | `""`    |
| `apps.wizarr.enabled`          | Back up Wizarr config PVC                                               | `false` |
| `apps.wizarr.configPvc`        | Name of Wizarr's config PVC                                             | `""`    |
| `apps.tunarr.enabled`          | Back up Tunarr config PVC                                               | `false` |
| `apps.tunarr.configPvc`        | Name of Tunarr's config PVC                                             | `""`    |

### Secret, storage & retention

| Parameter                  | Description                                                           | Default         |
| -------------------------- | --------------------------------------------------------------------- | --------------- |
| `existingSecret`           | Name of a Secret with per-app API keys (keys = `radarr`, `sonarr`, …) | `""`            |
| `storage.nfs.server`       | NFS server address (e.g. `192.168.1.100`)                             | `""`            |
| `storage.nfs.path`         | NFS export path                                                       | `""`            |
| `storage.storageClassName` | StorageClass for the chart-managed PV/PVC                             | `""`            |
| `storage.accessMode`       | PV/PVC access mode                                                    | `ReadWriteMany` |
| `storage.capacity`         | PV/PVC size                                                           | `100Gi`         |
| `retention.enabled`        | Delete old backups                                                    | `true`          |
| `retention.days`           | Retention window in days                                              | `30`            |

### Job, RBAC & ServiceAccount

| Parameter                    | Description                                                                                             | Default           |
| ---------------------------- | ------------------------------------------------------------------------------------------------------- | ----------------- |
| `successfulJobsHistoryLimit` | CronJob successful-history retention                                                                    | `3`               |
| `failedJobsHistoryLimit`     | CronJob failed-history retention                                                                        | `3`               |
| `serviceAccount.create`      | Create a ServiceAccount for the CronJob                                                                 | `true`            |
| `serviceAccount.name`        | Reuse an existing ServiceAccount (when `create: false`)                                                 | `""`              |
| `serviceAccount.annotations` | Annotations on the SA                                                                                   | `{}`              |
| `rbac.create`                | Force-create Role + RoleBinding (`pods/exec`). Automatically `true` when any filesystem app is enabled. | `false`           |
| `resources`                  | Container resource requests/limits                                                                      | See `values.yaml` |
| `podAnnotations`             | Pod annotations                                                                                         | `{}`              |
| `nodeSelector`               | Node selector                                                                                           | `{}`              |
| `tolerations`                | Tolerations                                                                                             | `[]`              |
| `affinity`                   | Affinity rules                                                                                          | `{}`              |

## Examples

### Servarr-only nightly backups

```yaml
schedule: "0 3 * * *"
timezone: "Europe/Paris"

existingSecret: backuparr-keys

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

storage:
  nfs:
    server: "192.168.1.100"
    path: "/exports/backups"
  storageClassName: ""
  accessMode: ReadWriteMany
  capacity: "200Gi"

retention:
  enabled: true
  days: 30
```

### Full stack — API + filesystem apps with auto-RBAC

```yaml
schedule: "30 2 * * *"
timezone: "America/Chicago"

existingSecret: backuparr-keys

apps:
  # API-based
  radarr:
    enabled: true
    url: "http://radarr.media.svc.cluster.local:7878"
  sonarr:
    enabled: true
    url: "http://sonarr.media.svc.cluster.local:8989"
  prowlarr:
    enabled: true
    url: "http://prowlarr.media.svc.cluster.local:9696"
    apiVersion: "v1"
  sabnzbd:
    enabled: true
    url: "http://sabnzbd.downloads.svc.cluster.local:8080"
  seerr:
    enabled: true
    url: "http://overseerr.media.svc.cluster.local:5055"

  # Filesystem-based (RBAC + PVC mounts are wired up automatically)
  bazarr:
    enabled: true                    # backed up via kubectl exec
  jellyfin:
    enabled: true
    configPvc: "jellyfin-config"
  kapowarr:
    enabled: true
    configPvc: "kapowarr-config-pvc"
  wizarr:
    enabled: true
    configPvc: "wizarr-data-pvc"

storage:
  nfs:
    server: "192.0.2.50"
    path: "/exports/backups"
  accessMode: ReadWriteMany
  capacity: "500Gi"

retention:
  enabled: true
  days: 60

resources:
  limits:
    cpu: "1"
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 256Mi
```

When any of `apps.bazarr|jellyfin|tdarr|kapowarr|lazylibrarian|wizarr|tunarr` is enabled, the chart automatically renders a `Role`/`RoleBinding` granting `pods/exec` to the CronJob's ServiceAccount, and `kubectl` is installed into the job pod at runtime.

## Persistence

Backuparr creates one `PersistentVolume` and one `PersistentVolumeClaim` per release, both backed by the NFS export defined in `storage.nfs`. The PV uses `persistentVolumeReclaimPolicy: Retain` — uninstalling the chart will leave the PV (and the backups on disk) untouched. To rewire to a different backend (Ceph, Longhorn, S3 CSI), edit `templates/pv.yaml` accordingly.

Per-run filesystem backups also mount the _source_ app's config PVCs into the job pod (read-only) at `/config/<app>`. These PVCs must already exist and must be `ReadWriteMany` if the source app is concurrently running on a different node — otherwise the backup will race for the volume.

## Integration notes

- **Servarr apps**: configure `apps.<app>.url` with the in-cluster Service DNS, e.g. `http://radarr.media.svc.cluster.local:7878`. The backup script triggers `POST /api/<version>/command {"name":"Backup"}`, polls `GET /api/<version>/command/<id>` until status is `completed`, then lists `/api/<version>/system/backup` to verify. **Note**: Servarr does not expose a download endpoint; the backup file remains inside the app's config directory. To capture the file itself, also enable the matching filesystem entry where applicable.
- **Bazarr**: backed up via `kubectl exec` into the running Bazarr pod. The script discovers the pod by label and triggers Bazarr's backup, then collects the resulting archive. This is why `pods/exec` RBAC is required.
- **Mounted-PVC apps** (Jellyfin, Tdarr, Kapowarr, LazyLibrarian, Wizarr, Tunarr): the chart mounts the named PVC read-only at `/config/<app>` inside the backup job and tar/gz's the relevant subtree. Because these PVCs are typically `ReadWriteOnce`, the backup job will be scheduled to the same node as the source pod — make sure your CSI driver supports cross-pod RWO sharing or your apps run on multi-attach RWX volumes.

## Upgrading

### To 1.2.x

- Filesystem app coverage broadened: Bazarr, Jellyfin, Tdarr, Kapowarr, LazyLibrarian, Wizarr, Tunarr.
- RBAC for `pods/exec` is now generated automatically whenever any filesystem app is enabled — you no longer need to set `rbac.create: true` manually for the standard cases.

Always test the new schedule against a non-production namespace first; the job runs with `concurrencyPolicy: Forbid`, so a long-running backup will block the next slot.

## Support

- Chart issues: [github.com/geekxflood/helm-charts/issues](https://github.com/geekxflood/helm-charts/issues)

## License

This Helm chart is licensed under the Apache License 2.0. The applications it backs up are distributed under their own licenses; consult each project's repository for details.

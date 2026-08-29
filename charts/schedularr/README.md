# Schedularr Helm Chart

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: v0.1.0](https://img.shields.io/badge/AppVersion-v0.1.0-informational?style=flat-square)

[Schedularr](https://github.com/christopherime/schedularr) generates and applies TV channel schedules for [Tunarr](https://tunarr.com). Scheduling rules ("blocks") define a time slot, a cron expression, a target channel, and a content filter; Schedularr resolves each block against Tunarr's library on a timer and pushes the result back. Deploy this chart next to Tunarr when you want channel programming that runs itself instead of being dragged onto a timeline by hand.

## Features

- Gateway API `HTTPRoute` exposure (no `Ingress` template — this app is meant to stay off any public-facing controller; front it with an internal-only Gateway listener)
- Generated `ConfigMap` for `config.yaml`, mounted read-only at `/etc/schedularr/config.yaml` (the image's default `--config` path)
- `SCHEDULARR_API_TOKEN` via `envFrom`/`existingSecret` — **never** rendered into the ConfigMap; the env var always wins over a config-file token per the app's own precedence rule
- Chart-managed PVC for the SQLite database (`config.database`) and the `scheduler.yaml` first-run import file (`config.schedulerFile`), or bring `persistence.existingClaim`
- `Recreate` deployment strategy — SQLite is single-writer, so a rolling update is never safe here (this chart never renders an HPA)
- Non-root, read-only-root-filesystem pod security context matching the image's own `uid 1001` user, with a writable `/tmp` `emptyDir`
- `/healthz` liveness and `/readyz` readiness probes (the latter does a store round-trip)
- ConfigMap checksum annotation on the deployment — pods restart automatically on config change

## Prerequisites

- Kubernetes 1.19+ (Gateway API CRDs `gateway.networking.k8s.io/v1` if `httpRoute.enabled=true`)
- Helm 3.0+
- A reachable Tunarr instance (same-namespace `http://tunarr:8000` by convention) — Tunarr's own API needs no credential
- A PV provisioner if `persistence.enabled=true` (the default) and no `existingClaim` is supplied
- A pre-existing Secret holding `SCHEDULARR_API_TOKEN` (see [Token setup](#token-setup) below) unless you intentionally run with `config.api.insecureNoAuth=true`

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install with default values

```bash
helm install schedularr geekxflood/schedularr --set enabled=true \
  --set config.tunarr.url=http://tunarr:8000 \
  --set existingSecret=schedularr-api-token
```

Note: `enabled` defaults to `false` — manifests do not render until you set it to `true`.

### Install with custom values

```bash
helm install schedularr geekxflood/schedularr -f values.yaml
```

## Token setup

`schedularr serve` refuses to start with an empty or short (<32 character)
bearer token unless `config.api.insecureNoAuth` is `true`. Create the Secret
this chart's `existingSecret` value points at before installing:

```bash
kubectl create secret generic schedularr-api-token \
  --namespace media \
  --from-literal=SCHEDULARR_API_TOKEN="$(openssl rand -hex 32)"
```

The Secret's own key name (`SCHEDULARR_API_TOKEN`) is what matters — the
chart mounts the whole Secret via `envFrom`, so it becomes the environment
variable of the same name inside the container. The web UI then needs the
same value pasted into its token panel (`Authorization: Bearer <token>` on
every `/api/v1/*` call — see the app README's "Token Setup" section).

## Configuration

### Image

| Parameter           | Description                              | Default                          |
| -------------------- | ----------------------------------------- | --------------------------------- |
| `enabled`            | Render manifests                          | `false`                           |
| `image.repository`   | Image repository                          | `ghcr.io/christopherime/schedularr` |
| `image.tag`          | Image tag (defaults to Chart appVersion)  | `""`                               |
| `image.pullPolicy`   | Image pull policy                         | `IfNotPresent`                     |
| `replicaCount`       | Replica count (keep at `1` — SQLite)      | `1`                                 |

### Service

| Parameter      | Description   | Default     |
| -------------- | ------------- | ----------- |
| `service.type` | Service type  | `ClusterIP` |
| `service.port` | HTTP API port | `8484`      |

### HTTPRoute (Gateway API)

| Parameter               | Description                                            | Default |
| ----------------------- | -------------------------------------------------------- | ------- |
| `httpRoute.enabled`     | Enable Gateway API HTTPRoute                              | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                                     | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                                          | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments (required when enabled)    | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                               | `[]`    |
| `httpRoute.rules`       | Route rules (matches + backendRefs)                       | `[]`    |

Omitted `backendRefs[*].name`/`port` target this chart's service on
`service.port` (8484).

### Application config (`config.*`)

Every key below is rendered verbatim into the ConfigMap's `config.yaml` and
maps 1:1 onto the app repo's `cmd/schema/config.cue` (`#Config`) — see that
file for the authoritative schema and defaults.

| Chart value (`config.*`)              | Rendered config key            | CUE default          | Notes                                                                 |
| -------------------------------------- | ------------------------------- | --------------------- | ---------------------------------------------------------------------- |
| `tunarr.url`                           | `tunarr.url`                    | (required)             | e.g. `http://tunarr:8000`                                              |
| `tunarr.apiKey`                        | `tunarr.api_key`                | `""`                   | Tunarr's API is unauthenticated upstream — usually left empty          |
| `tunarr.timeout`                       | `tunarr.timeout`                | `30s`                  | Request timeout                                                        |
| `log.level`                            | `log.level`                     | `info`                 | `debug`, `info`, `warn`, `error`                                       |
| `log.format`                           | `log.format`                    | `text`                 | `text` or `json`                                                       |
| `log.timezone`                         | `log.timezone`                  | `Local`                | IANA time zone name                                                     |
| `database`                             | `database`                      | `schedularr.db`        | Chart default: `/data/schedularr.db` — keep under `persistence.mountPath` |
| `schedulerFile`                        | `scheduler_file`                | `scheduler.yaml`       | Chart default: `/data/scheduler.yaml` — first-run import only, see below |
| `cronInterval`                         | `cron_interval`                 | `6h`                   | `serve`'s regenerate-and-apply cadence                                 |
| `maintenance.historyRetention`         | `maintenance.history_retention` | `168h`                 | Bounds `GET /history?days=N`; widen for a full 90-day query window     |
| `maintenance.cleanupEnabled`           | `maintenance.cleanup_enabled`   | `true`                 | Background history cleanup                                             |
| `api.listen`                           | `api.listen`                    | `:8484`                | Should match `service.port`                                            |
| `api.insecureNoAuth`                   | `api.insecure_no_auth`          | `false`                | Never set `true` in a real deployment                                  |
| — (never rendered)                     | `api.token`                     | `""`                   | Deliberately omitted — see [Token setup](#token-setup)                 |

`scheduler_file` (`config.schedulerFile`) is a **first-run import format
only**: the first time the SQLite store is empty, its blocks are imported
once. After that, manage blocks going forward through the `/api/v1/blocks`
HTTP API or the web UI — editing the file again has no effect.

### Persistence

| Parameter                    | Description                              | Default         |
| ------------------------------ | ----------------------------------------- | --------------- |
| `persistence.enabled`          | Create a data PVC                         | `true`           |
| `persistence.existingClaim`    | Reuse an existing PVC (skip creation)     | `""`             |
| `persistence.storageClass`     | Storage class                              | `""`             |
| `persistence.accessMode`       | Access mode                                | `ReadWriteOnce`  |
| `persistence.size`             | PVC size                                   | `2Gi`            |
| `persistence.mountPath`        | Mount path inside the container            | `/data`          |

`persistence.enabled` should stay `true` for any real deployment: Schedularr
has no alternate backend, and with the chart's default
`readOnlyRootFilesystem: true` the container has nowhere else to create the
SQLite file if `/data` isn't a mounted volume. If you change
`persistence.mountPath`, also update `config.database` and
`config.schedulerFile` to match — the chart does not derive the config paths
from the mount path automatically.

### Resources, Probes, Security

| Parameter                   | Description                     | Default            |
| ----------------------------- | -------------------------------- | -------------------- |
| `resources`                  | CPU/memory requests and limits   | `{}`                  |
| `livenessProbe`              | HTTP `GET /healthz`              | see `values.yaml`      |
| `readinessProbe`             | HTTP `GET /readyz` (checks the store) | see `values.yaml` |
| `podSecurityContext`         | Pod-level security context       | non-root, uid/gid 1001 |
| `securityContext`            | Container-level security context | read-only root fs, all caps dropped |
| `nodeSelector`                | Node selector                    | `{}`                  |
| `affinity`                    | Affinity rules                   | `{}`                  |
| `tolerations`                 | Tolerations                      | `[]`                  |

### Secrets & Environment

| Parameter         | Description                                                | Default |
| ------------------- | ------------------------------------------------------------ | ------- |
| `existingSecret`    | Secret name providing `SCHEDULARR_API_TOKEN` via `envFrom`   | `""`    |
| `env`               | Additional plain `{name, value}` env vars                    | `[]`    |
| `envFrom`           | Additional refs into Secret/ConfigMap: `{type, name}` items  | `[]`    |

## Examples

### HTTPRoute behind an internal Gateway, persistent config, existing token Secret

```yaml
enabled: true

image:
  tag: "v0.1.0"

config:
  tunarr:
    url: http://tunarr:8000
  maintenance:
    historyRetention: 2160h  # 90 days, so GET /history?days=90 is truthful

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - schedularr.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1

persistence:
  enabled: true
  storageClass: fast-ssd
  size: 2Gi

existingSecret: schedularr-api-token

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

Cilium operators: `parentRefs[*].port` is ignored — target a listener via
`sectionName`. Cross-namespace `backendRefs` require a `ReferenceGrant`.

This chart never renders an `Ingress` — keep Schedularr off any
publicly-reachable controller and expose it only through an internal Gateway
listener or `kubectl port-forward`.

## Persistence

Schedularr keeps two files on the data PVC: the SQLite database
(`config.database`, default `/data/schedularr.db`, opened with
`_busy_timeout=5000&_journal_mode=WAL` — expect `-shm`/`-wal` sidecar files
alongside it) and, only for the first-run bootstrap, `scheduler_file`
(default `/data/scheduler.yaml`).

Snapshot the database before any major image bump:

```bash
kubectl exec deploy/schedularr -- sh -c \
  "sqlite3 /data/schedularr.db \".backup '/tmp/schedularr-$(date +%F).db'\"" \
  && kubectl cp <pod>:/tmp/schedularr-$(date +%F).db ./schedularr-backup.db
```

(`schedularr state backup <file>` does the same `VACUUM INTO` from inside
the CLI, if you exec into the container instead.)

**Backup coverage note**: this chart's PVC is not covered by the cluster's
`backuparr` chart as of this writing — schedularr is not one of the
apps backuparr knows how to snapshot. Back it up manually or via the wiki's
documented process until that gap is closed.

## Upgrading

Schema migrations run on startup via `golang-migrate`. The deployment
carries a `checksum/config` annotation on its pod template, so any change to
`config.*` triggers a restart (the `Recreate` strategy tears the old pod
down first — expect a short gap in the `/healthz` probe during upgrades).
Always snapshot the database before bumping `image.tag`.

## Support

- Upstream project: <https://github.com/christopherime/schedularr>
- Tunarr: <https://tunarr.com/>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. Schedularr is licensed under the MIT License.

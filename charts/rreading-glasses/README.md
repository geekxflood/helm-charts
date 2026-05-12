# rreading-glasses Helm Chart

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

A Helm chart for deploying [rreading-glasses](https://github.com/blampe/rreading-glasses) on Kubernetes. rreading-glasses is a self-hosted metadata service that stands in for the upstream metadata endpoints used by book and audiobook management apps (most commonly Readarr). It proxies, normalizes, and caches lookups against Goodreads or Hardcover so your library scanner is no longer at the mercy of upstream rate limits and outages.

## Overview

Readarr's metadata pipeline depends on third-party services that have become unreliable. rreading-glasses fronts those providers with a local PostgreSQL-backed cache, exposing a metadata API on port `8788` that Readarr (and similar consumers) can be pointed at. The chart bundles a single-replica deployment, an internal PostgreSQL `StatefulSet` (with the option to switch to an external database), and the wiring to flip the upstream between Goodreads and Hardcover.

The upstream binary is invoked as `/main serve --upstream=www.goodreads.com` (the chart defaults), but you can swap `--upstream` to `www.hardcover.app` or any compatible host through `args`.

## Features

- **Embedded PostgreSQL** via `StatefulSet` + headless Service, with its own `PersistentVolumeClaim` template and a generated password Secret (only when `existingSecret` is empty).
- **External PostgreSQL** alternative — point at any existing database with `postgresql.external.*` (host, port, database, username, secret reference).
- **Provider switch** — Goodreads (default) or Hardcover (set `metadata.provider: hardcover` and supply an API token via Secret).
- **Auto-injected database env** — `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DATABASE`, `POSTGRES_USER`, and `POSTGRES_PASSWORD` are wired from the chosen PostgreSQL config; `HARDCOVER_API_TOKEN` is injected only when the Hardcover provider is selected.
- **Config-hash pod annotation** — pod template gets `checksum/config` so config changes trigger a rollout.
- **TCP-socket probes** on port `8788` (the metadata service does not expose a friendly HTTP health path).
- **Ingress** and **Gateway API HTTPRoute** exposure.
- **Cloudflare Tunnel** via `TunnelBinding` (`cfTunnel.*`, requires cloudflare-operator).
- **Optional HorizontalPodAutoscaler** for cache-heavy workloads.

## Prerequisites

- Kubernetes 1.19+ (Gateway API 1.0+ if using `httpRoute`; cloudflare-operator CRDs if using `cfTunnel`)
- Helm 3.0+
- Persistent storage for the embedded PostgreSQL (or an existing PostgreSQL 13+ database for external mode)
- A consumer that speaks the Readarr metadata protocol — typically Readarr itself, pointed at this chart's Service

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install rreading-glasses geekxflood/rreading-glasses -f values.yaml
```

The chart defaults to `enabled: false`. You must override it.

## Configuration

### Core Parameters

| Parameter          | Description                                          | Default                       |
| ------------------ | ---------------------------------------------------- | ----------------------------- |
| `enabled`          | Master switch                                        | `false`                       |
| `replicaCount`     | Pod replicas                                         | `1`                           |
| `image.repository` | Container image                                      | `blampe/rreading-glasses`     |
| `image.tag`        | Image tag (`latest` = Goodreads; `hardcover` = Hardcover) | `latest`                 |
| `image.pullPolicy` | Image pull policy                                    | `IfNotPresent`                |
| `command`          | Container entrypoint (do not change unless upstream changes) | `["/main", "serve"]`  |
| `args`             | Container args — `--upstream` is **required**        | `["--upstream=www.goodreads.com", "--verbose"]` |
| `env`              | Extra environment variables                          | `[]`                          |

### Service Account

| Parameter                    | Description                | Default |
| ---------------------------- | -------------------------- | ------- |
| `serviceAccount.create`      | Create a ServiceAccount    | `true`  |
| `serviceAccount.automount`   | Automount the token        | `true`  |
| `serviceAccount.annotations` | Annotations on the SA      | `{}`    |
| `serviceAccount.name`        | Use an existing SA name    | `""`    |

### Service

| Parameter      | Description           | Default     |
| -------------- | --------------------- | ----------- |
| `service.type` | Service type          | `ClusterIP` |
| `service.port` | Metadata API port     | `8788`      |

### Embedded PostgreSQL (`postgresql.internal.*`)

| Parameter                                  | Description                                          | Default              |
| ------------------------------------------ | ---------------------------------------------------- | -------------------- |
| `postgresql.enabled`                       | Master toggle for the PostgreSQL block               | `true`               |
| `postgresql.internal.enabled`              | Run an embedded PostgreSQL StatefulSet               | `true`               |
| `postgresql.internal.auth.database`        | Database name                                        | `rreading_glasses`   |
| `postgresql.internal.auth.username`        | DB username                                          | `rreading_glasses`   |
| `postgresql.internal.auth.password`        | Plaintext password (used to seed the chart-managed Secret if `existingSecret` is empty) | `change_me_password` |
| `postgresql.internal.auth.existingSecret`  | Reuse an existing Secret (key `password`)            | `""`                 |
| `postgresql.internal.storage.storageClass` | StorageClass for the PVC template                    | `""` (cluster default) |
| `postgresql.internal.storage.size`         | PVC size                                             | `10Gi`               |

The embedded PostgreSQL is `postgres:16-alpine`, runs as a one-replica `StatefulSet`, exposes a headless Service named `<release>-rreading-glasses-postgresql`, and is reachable from the application on port `5432`.

### External PostgreSQL (`postgresql.external.*`)

Enable `postgresql.external.enabled: true` **and** set `postgresql.internal.enabled: false` to disable the embedded database. The application reads the password from a Secret you provide.

| Parameter                                  | Description                                  | Default              |
| ------------------------------------------ | -------------------------------------------- | -------------------- |
| `postgresql.external.enabled`              | Use an external PostgreSQL                   | `false`              |
| `postgresql.external.host`                 | Hostname / Service                           | `""`                 |
| `postgresql.external.port`                 | Port                                         | `5432`               |
| `postgresql.external.database`             | Database name                                | `rreading_glasses`   |
| `postgresql.external.username`             | DB username                                  | `rreading_glasses`   |
| `postgresql.external.existingSecret`       | Secret containing the DB password            | `""`                 |
| `postgresql.external.secretKey`            | Key within the Secret                        | `change_me_secret_key` |

### Metadata provider

| Parameter                            | Description                                                                 | Default     |
| ------------------------------------ | --------------------------------------------------------------------------- | ----------- |
| `metadata.provider`                  | `goodreads` or `hardcover`                                                  | `goodreads` |
| `metadata.hardcover.apiToken`        | Hardcover API token (used to seed a chart-managed Secret if no external one) | `""`        |
| `metadata.hardcover.existingSecret`  | Existing Secret containing the Hardcover token                              | `""`        |
| `metadata.hardcover.secretKey`       | Key within the Hardcover Secret                                             | `api-token` |

When `metadata.provider: hardcover`, the application receives a `HARDCOVER_API_TOKEN` env var from the referenced Secret. You also typically want to switch `args` to `--upstream=www.hardcover.app` and (optionally) `image.tag: hardcover`.

### Ingress / HTTPRoute / Cloudflare Tunnel

Identical pattern to the other charts in this repo.

| Parameter                | Description                              | Default |
| ------------------------ | ---------------------------------------- | ------- |
| `ingress.enabled`        | Create an Ingress                        | `false` |
| `ingress.className`      | IngressClass name                        | `""`    |
| `ingress.annotations`    | Ingress annotations                      | `{}`    |
| `ingress.hosts`          | Host/path definitions                    | `[]`    |
| `ingress.tls`            | TLS host/secret pairs                    | `[]`    |
| `httpRoute.enabled`      | Create a Gateway API `HTTPRoute`         | `false` |
| `httpRoute.parentRefs`   | Gateway / Listener attachments           | `[]`    |
| `httpRoute.hostnames`    | Matched hostnames                        | `[]`    |
| `httpRoute.rules`        | Route rules                              | `[]`    |
| `cfTunnel.enabled`       | Create a `TunnelBinding`                 | `false` |
| `cfTunnel.tunnelRef`     | Reference to a `ClusterTunnel`/`Tunnel`  | `{}`    |
| `cfTunnel.subjects`      | TunnelBinding subjects                   | `[]`    |

### Resources & Probes

| Parameter                  | Description                                  | Default                                |
| -------------------------- | -------------------------------------------- | -------------------------------------- |
| `resources.limits.memory`  | Memory limit                                 | `512Mi`                                |
| `resources.requests.cpu`   | CPU request                                  | `100m`                                 |
| `resources.requests.memory`| Memory request                               | `256Mi`                                |
| `livenessProbe`            | TCP socket on port 8788                      | 30s delay, 30s period                  |
| `readinessProbe`           | TCP socket on port 8788                      | 15s delay, 15s period                  |
| `strategy`                 | Deployment strategy (`RollingUpdate`)        | `maxSurge: 1`, `maxUnavailable: 0`     |
| `autoscaling.enabled`      | Enable HPA                                   | `false`                                |
| `autoscaling.maxReplicas`  | HPA max replicas                             | `10`                                   |

## Examples

### Goodreads with embedded PostgreSQL

```yaml
enabled: true

# Use the chart's embedded PostgreSQL
postgresql:
  enabled: true
  internal:
    enabled: true
    auth:
      database: "rreading_glasses"
      username: "rreading_glasses"
      password: "a-strong-password-here"
    storage:
      size: 20Gi
      storageClass: longhorn

metadata:
  provider: goodreads

args:
  - --upstream=www.goodreads.com
  - --verbose

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: rreading.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: rreading-tls
      hosts:
        - rreading.example.com
```

### Hardcover with an external PostgreSQL

```yaml
enabled: true

image:
  repository: blampe/rreading-glasses
  tag: hardcover

postgresql:
  enabled: true
  internal:
    enabled: false
  external:
    enabled: true
    host: "pg.databases.svc.cluster.local"
    port: 5432
    database: "rreading_glasses"
    username: "rreading_glasses"
    existingSecret: "rreading-glasses-db"
    secretKey: "password"

metadata:
  provider: hardcover
  hardcover:
    existingSecret: "rreading-glasses-hardcover"
    secretKey: "api-token"

args:
  - --upstream=www.hardcover.app
  - --verbose
```

Pre-create the two Secrets:

```bash
kubectl create secret generic rreading-glasses-db \
  --from-literal=password=$(openssl rand -base64 24)

kubectl create secret generic rreading-glasses-hardcover \
  --from-literal=api-token=YOUR_HARDCOVER_TOKEN
```

## Persistence

The chart's persistence story applies to the **embedded PostgreSQL only**. The StatefulSet uses a `volumeClaimTemplates` entry sized by `postgresql.internal.storage.size` and the StorageClass from `postgresql.internal.storage.storageClass` (cluster default if blank). The application itself is stateless beyond the database.

If you bring an external PostgreSQL, no chart-managed PVCs are created.

## Integration notes

To wire Readarr (or any Readarr-compatible client) to this service:

1. Resolve the in-cluster Service name: typically `http://<release>-rreading-glasses.<namespace>.svc.cluster.local:8788`.
2. In Readarr's settings, override the metadata server URL with the address above. The exact field depends on your Readarr branch (`Readarr-Develop` or community forks); consult your fork's docs.
3. Hit the endpoint from a test pod to confirm reachability before pointing Readarr at it:

   ```bash
   kubectl run curl --rm -it --image=curlimages/curl --restart=Never -- \
     curl -sf http://rreading-glasses.media.svc.cluster.local:8788/
   ```

The first few lookups will be slow (cold cache); subsequent identical lookups are served from PostgreSQL.

## Upgrading

Chart `0.2.0` is the current line. When upgrading, watch out for two things:

- **Switching providers** (Goodreads ↔ Hardcover) does not invalidate the cache automatically — drop the PostgreSQL volume or run a manual truncate if you want a clean slate.
- **External-to-internal PostgreSQL** migrations require a `pg_dump`/`pg_restore`; the chart cannot copy data for you.

The embedded PostgreSQL image is pinned to `postgres:16-alpine` and is not configurable; switch to external mode if you need a different version.

## Support

- Upstream rreading-glasses: [github.com/blampe/rreading-glasses](https://github.com/blampe/rreading-glasses)
- Chart issues: [github.com/geekxflood/helm-charts/issues](https://github.com/geekxflood/helm-charts/issues)

## License

This Helm chart is licensed under the Apache License 2.0. rreading-glasses is distributed under its upstream license; consult the project repository for details.

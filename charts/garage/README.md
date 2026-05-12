# Garage Helm Chart

![Version: 1.1.1](https://img.shields.io/badge/Version-1.1.1-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: v2.3.0](https://img.shields.io/badge/AppVersion-v2.3.0-informational?style=flat-square)

A Helm chart that deploys [Garage](https://garagehq.deuxfleurs.fr/) — a lightweight, S3-compatible distributed object store from Deuxfleurs designed for small self-hosted geo-distributed deployments. Garage is well suited for storing backups (rclone, Restic, Velero), Loki/Mimir chunks, container registries, and static websites across two or three nodes without the operational cost of MinIO or Ceph.

This chart deploys Garage as a `StatefulSet` (default) or `DaemonSet`, generates `garage.toml` from values, exposes the S3 API, S3 web (static hosting), and admin endpoints, and integrates with Prometheus.

## Features

- `StatefulSet` (replicated PVCs, the recommended layout) or `DaemonSet` (host-path storage)
- Native Kubernetes peer discovery via `[kubernetes_discovery]` — no manual bootstrap peer list required
- LMDB or Sled DB engine selection
- Per-node split storage: metadata volume (`/mnt/meta`) and data volume (`/mnt/data`)
- Replication factor configurable (`replicationMode`) — `1`/`2`/`3`/`none`
- S3 API + S3 web (`vhost-style` static website hosting on a wildcard domain)
- zstd block compression with configurable level
- Configurable RPC secret loaded into `garage.toml` via init container from a Kubernetes `Secret`
- Ingress and Gateway API `HTTPRoute` for both `s3.api` and `s3.web`, independently toggleable
- Prometheus `Service` annotations and optional `ServiceMonitor`
- OpenTelemetry trace sink endpoint configurable

## Prerequisites

- Kubernetes 1.21+
- Helm 3.0+
- A `StorageClass` capable of `ReadWriteOnce` PVCs (sized for both metadata and data)
- For `httpRoute`: Gateway API CRDs and a working Gateway
- For `monitoring.metrics.serviceMonitor.enabled`: the Prometheus Operator
- For multi-zone replication, plan your node topology in advance — the RPC secret and `replicationMode` must be identical on every node and changing `replicationMode` after data is written is not supported in-place

## Installation

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm install garage geekxflood/garage
helm install garage geekxflood/garage -f values.yaml
```

**Important**: generate a real RPC secret before installing:

```bash
openssl rand -hex 32
```

Put the result in `garage.rpcSecret` (or pre-create the secret out-of-band — the chart's init container reads `/etc/garage/secret/rpc_secret` and substitutes it into `garage.toml`).

After install, configure the cluster layout with `garage layout`:

```bash
kubectl exec -n garage garage-0 -- /garage status
kubectl exec -n garage garage-0 -- /garage layout assign -z dc1 -c 100G <node-id>
kubectl exec -n garage garage-0 -- /garage layout apply --version 1
```

## Configuration

### Cluster

| Parameter                        | Description                                       | Default                           |
| -------------------------------- | ------------------------------------------------- | --------------------------------- |
| `garage.dbEngine`                | DB engine (`lmdb` or `sled`)                      | `lmdb`                            |
| `garage.blockSize`               | Block size in bytes                               | `1048576`                         |
| `garage.replicationMode`         | Replication factor (`1`/`2`/`3`/`none`)           | `2`                               |
| `garage.compressionLevel`        | zstd level for stored blocks                      | `1`                               |
| `garage.rpcBindAddr`             | RPC bind address                                  | `[::]:3901`                       |
| `garage.rpcSecret`               | 64-hex RPC secret (replace before install)        | `CHANGE_ME_GENERATE_NEW_SECRET_…` |
| `garage.bootstrapPeers`          | Static peer list (unnecessary with K8s discovery) | `[]`                              |
| `garage.kubernetesSkipCrd`       | Skip CRD registration in K8s discovery            | `false`                           |
| `deployment.kind`                | `StatefulSet` or `DaemonSet`                      | `StatefulSet`                     |
| `deployment.replicaCount`        | Replica count (`StatefulSet` only)                | `3`                               |
| `deployment.podManagementPolicy` | `OrderedReady` or `Parallel`                      | `OrderedReady`                    |

### S3 API & web

| Parameter                  | Description                                 | Default           |
| -------------------------- | ------------------------------------------- | ----------------- |
| `garage.s3.api.region`     | S3 region name                              | `garage`          |
| `garage.s3.api.rootDomain` | Vhost-style domain (e.g. `.s3.example.com`) | `.s3.garage.tld`  |
| `garage.s3.web.rootDomain` | Web hosting domain                          | `.web.garage.tld` |
| `garage.s3.web.index`      | Default index file                          | `index.html`      |
| `service.s3.api.port`      | S3 API service port                         | `3900`            |
| `service.s3.web.port`      | S3 web service port                         | `3902`            |

### Persistence

| Parameter                       | Description                | Default                |
| ------------------------------- | -------------------------- | ---------------------- |
| `persistence.enabled`           | Use PVCs (`StatefulSet`)   | `true`                 |
| `persistence.meta.size`         | Metadata PVC size          | `10Gi`                 |
| `persistence.meta.storageClass` | Metadata StorageClass      | `""` (cluster default) |
| `persistence.meta.hostPath`     | `DaemonSet`-only host path | `/var/lib/garage/meta` |
| `persistence.data.size`         | Data PVC size              | `100Gi`                |
| `persistence.data.storageClass` | Data StorageClass          | `""` (cluster default) |
| `persistence.data.hostPath`     | `DaemonSet`-only host path | `/var/lib/garage/data` |

### Ingress / HTTPRoute

| Parameter                                                           | Description                  | Default           |
| ------------------------------------------------------------------- | ---------------------------- | ----------------- |
| `ingress.s3.api.enabled` / `web.enabled`                            | Per-endpoint ingress toggles | `false`           |
| `ingress.s3.<api\|web>.className` / `annotations` / `hosts` / `tls` | Standard ingress wiring      | see `values.yaml` |
| `httpRoute.enabled`                                                 | Master Gateway API toggle    | `false`           |
| `httpRoute.s3.api.enabled` / `httpRoute.s3.web.enabled`             | Per-endpoint route toggles   | `false`           |
| `httpRoute.s3.<api\|web>.parentRefs` / `hostnames` / `rules`        | Standard HTTPRoute wiring    | `[]`              |

Both ingress and HTTPRoute may coexist; back-ends default to this chart's `Service` on `service.s3.api.port` / `service.s3.web.port` when omitted. Cilium ignores `parentRefs[*].port` — use `sectionName`. Cross-namespace `backendRefs` require a `ReferenceGrant`.

### Monitoring

| Parameter                                                                 | Description                                    | Default           |
| ------------------------------------------------------------------------- | ---------------------------------------------- | ----------------- |
| `monitoring.metrics.enabled`                                              | Add `prometheus.io/scrape` Service annotations | `true`            |
| `monitoring.metrics.serviceMonitor.enabled`                               | Render a `ServiceMonitor`                      | `true`            |
| `monitoring.metrics.serviceMonitor.interval` / `scrapeTimeout` / `labels` | Scrape config                                  | see `values.yaml` |
| `monitoring.tracing.sink`                                                 | OTLP trace sink endpoint                       | `""`              |

### Resources & scheduling

| Parameter                                   | Description                                           | Default                   |
| ------------------------------------------- | ----------------------------------------------------- | ------------------------- |
| `resources.requests` / `limits`             | Per-pod resources                                     | `100m`/`512Mi`, `–`/`2Gi` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls                          | `{}` / `[]` / `{}`        |
| `podSecurityContext` / `securityContext`    | Restricted by default; `readOnlyRootFilesystem: true` | see `values.yaml`         |

## Examples

### Three-node S3 cluster on PVCs with Ingress and ServiceMonitor

```yaml
deployment:
  kind: StatefulSet
  replicaCount: 3

garage:
  dbEngine: lmdb
  replicationMode: "3"
  rpcSecret: "REPLACE_WITH_openssl_rand_hex_32"
  s3:
    api:
      region: us-east-1
      rootDomain: ".s3.example.com"
    web:
      rootDomain: ".web.example.com"

persistence:
  meta:
    size: 20Gi
    storageClass: fast-ssd
  data:
    size: 1Ti
    storageClass: bulk-storage

ingress:
  s3:
    api:
      enabled: true
      className: nginx
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-production
        nginx.ingress.kubernetes.io/proxy-body-size: "0"
      hosts:
        - host: s3.example.com
          paths: [{ path: /, pathType: Prefix }]
        - host: "*.s3.example.com"
          paths: [{ path: /, pathType: Prefix }]
      tls:
        - secretName: garage-s3-api-tls
          hosts: [s3.example.com, "*.s3.example.com"]

monitoring:
  metrics:
    serviceMonitor:
      enabled: true
      labels:
        release: kube-prometheus-stack
```

### DaemonSet on dedicated storage nodes with HTTPRoute

```yaml
deployment:
  kind: DaemonSet

garage:
  replicationMode: "2"
  rpcSecret: "REPLACE_WITH_openssl_rand_hex_32"

nodeSelector:
  storage-node: "true"

persistence:
  enabled: false  # DaemonSet uses hostPath
  meta:
    hostPath: /srv/garage/meta
  data:
    hostPath: /srv/garage/data

ingress:
  s3:
    api: { enabled: false }
    web: { enabled: false }

httpRoute:
  enabled: true
  s3:
    api:
      enabled: true
      parentRefs:
        - { name: cilium-gateway, namespace: gateway-system, sectionName: https }
      hostnames: [s3.example.com, "*.s3.example.com"]
      rules:
        - matches: [{ path: { type: PathPrefix, value: / } }]
          backendRefs: [{}]
    web:
      enabled: true
      parentRefs:
        - { name: cilium-gateway, namespace: gateway-system, sectionName: https }
      hostnames: ["*.web.example.com"]
      rules:
        - matches: [{ path: { type: PathPrefix, value: / } }]
          backendRefs: [{}]
```

## Persistence

Garage is split storage by design — keep metadata on **fast** (NVMe / SSD) storage and bulk data on **cheaper but larger** storage. Sizing rule of thumb: metadata at ~1% of data volume, never less than 5 GiB. With `replicationMode: 3`, raw capacity equals one third of the sum of node data volumes. When using a `DaemonSet`, use `hostPath` and rely on local SSDs.

Do not change `replicationMode` after putting data into the cluster — re-replication is a manual `garage repair` workflow.

## Integration notes

- **rclone / Restic / Velero**: any S3-compatible client works. Endpoint is `https://s3.example.com`, region is `garage.s3.api.region`, and credentials come from `garage key new` (run inside any pod).
- **Static websites**: upload to a bucket, enable web mode with `garage bucket website --allow <bucket>`, and point a wildcard DNS record at the `s3.web` endpoint.
- **postgres-ha backups**: configure `barmanObjectStore.destinationPath: s3://backups/postgres` and reference an S3 credentials `Secret` containing keys generated by Garage.
- **Cluster layout** is **not** managed by Helm — after install, every new node must be assigned to the layout (`garage layout assign`) and a layout version applied. Helm will not do this for you.
- **Admin API** (port 3903) is intentionally not exposed by the `Service` — it is not consistent across nodes. Use `kubectl exec` for admin tasks.

## Upgrading

- **Across minor Garage versions**: roll the `StatefulSet` one pod at a time. Verify `garage status` shows the rolled node as `up` before proceeding.
- **RPC secret rotation** requires a full cluster restart with the new secret in place; you cannot mix old and new secrets across nodes.
- **`replicationMode` changes** are unsupported on a populated cluster.

## Support

- Upstream: <https://garagehq.deuxfleurs.fr/> · <https://git.deuxfleurs.fr/Deuxfleurs/garage>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

- Chart: Apache License 2.0
- Garage: [AGPL-3.0](https://git.deuxfleurs.fr/Deuxfleurs/garage/src/branch/main/LICENSE)

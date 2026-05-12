# overseer Helm Chart

![Version: 0.4.0](https://img.shields.io/badge/Version-0.4.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.33.2](https://img.shields.io/badge/AppVersion-1.33.2-informational?style=flat-square)

A trimmed-down Helm chart for deploying [Overseerr](https://overseerr.dev) on Kubernetes — pinned to a specific Overseerr release (`1.33.2`) and shipping a smaller surface area than the [`overseerr`](../overseerr) chart in this repository.

This is **not a separate application**. Both `overseer` and `overseerr` deploy the upstream Overseerr request/discovery manager for Plex. The differences are operational:

| Concern             | `overseer`                                                | `overseerr`                    |
| ------------------- | --------------------------------------------------------- | ------------------------------ |
| Pinned appVersion   | `1.33.2`                                                  | `1.35.0`                       |
| Image (default)     | `lscr.io/linuxserver/overseerr:latest`                    | `linuxserver/overseerr:1.35.0` |
| `envFrom` support   | No                                                        | Yes                            |
| `runtime.*` support | No                                                        | Yes                            |
| Cloudflare Tunnel   | No                                                        | Yes                            |
| HPA template        | No (`autoscaling` flag exists but no template renders it) | Yes                            |
| Built-in PVC        | Yes — hardcoded `synology-csi-iscsi-retain` static PVC    | No — bring your own            |
| Probes              | Optional via `livenessProbe` / `readinessProbe` values    | Not exposed                    |

If you don't have a strong reason to pick this chart, use [`overseerr`](../overseerr) — it has more knobs and tracks newer upstream releases. Use `overseer` when you want a minimal, opinionated deployment and the bundled Synology iSCSI PVC matches your environment.

## Features

- Minimal deployment of Overseerr with configurable image, replicas, resources, and pod metadata.
- Optional `livenessProbe` and `readinessProbe` (rendered only when present in values).
- `Recreate` deployment strategy for `ReadWriteOnce` storage.
- HTTP service on port 5055 with optional `Ingress`.
- Optional Gateway API `HTTPRoute` for vanilla Kubernetes Gateway implementations.
- A bundled `PersistentVolumeClaim` (`overseer-config-iscsi-pvc`, 5 GiB, `synology-csi-iscsi-retain`) — see [Persistence](#persistence) before installing.
- Arbitrary `volumes` / `volumeMounts` for the config mount and any extras.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- A running Plex Media Server reachable from the pod.
- Either the `synology-csi-iscsi-retain` `StorageClass` available in the cluster, **or** you must override / disable the bundled PVC template before installing (see Persistence).

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install overseer geekxflood/overseer
```

### Install with custom values

```bash
helm install overseer geekxflood/overseer -f values.yaml
```

## Configuration

### Global Parameters

| Parameter      | Description                         | Default |
| -------------- | ----------------------------------- | ------- |
| `enabled`      | Enable/disable the chart deployment | `false` |
| `replicaCount` | Number of replicas                  | `1`     |

### Image Parameters

| Parameter          | Description        | Default                         |
| ------------------ | ------------------ | ------------------------------- |
| `image.repository` | Image repository   | `lscr.io/linuxserver/overseerr` |
| `image.pullPolicy` | Image pull policy  | `Always`                        |
| `image.tag`        | Image tag          | `"latest"`                      |
| `imagePullSecrets` | Image pull secrets | `[]`                            |

### Service Account Parameters

| Parameter                    | Description                     | Default |
| ---------------------------- | ------------------------------- | ------- |
| `serviceAccount.create`      | Create service account          | `true`  |
| `serviceAccount.automount`   | Automount service account token | `true`  |
| `serviceAccount.annotations` | Service account annotations     | `{}`    |
| `serviceAccount.name`        | Service account name override   | `""`    |

### Pod Parameters

| Parameter            | Description                | Default    |
| -------------------- | -------------------------- | ---------- |
| `nameOverride`       | Override chart name        | `""`       |
| `fullnameOverride`   | Override full release name | `""`       |
| `podAnnotations`     | Pod annotations            | `{}`       |
| `podLabels`          | Pod labels                 | `{}`       |
| `podSecurityContext` | Pod security context       | `{}`       |
| `securityContext`    | Container security context | `{}`       |
| `strategy.type`      | Deployment strategy        | `Recreate` |

### Environment Variables

| Parameter | Description                                  | Default |
| --------- | -------------------------------------------- | ------- |
| `env`     | Literal env vars (`PUID`, `PGID`, `TZ`, ...) | `[]`    |

> `envFrom` is **not** supported by this chart. If you need to inject configuration from a `Secret` / `ConfigMap`, switch to the [`overseerr`](../overseerr) chart.

### Service Parameters

| Parameter      | Description    | Default     |
| -------------- | -------------- | ----------- |
| `service.type` | Service type   | `ClusterIP` |
| `service.port` | Overseerr port | `5055`      |

### Ingress Parameters

| Parameter             | Description                 | Default |
| --------------------- | --------------------------- | ------- |
| `ingress.enabled`     | Enable Ingress              | `false` |
| `ingress.className`   | Ingress class name          | `""`    |
| `ingress.annotations` | Ingress annotations         | `{}`    |
| `ingress.hosts`       | Ingress hosts configuration | `[]`    |
| `ingress.tls`         | Ingress TLS configuration   | `[]`    |

### HTTPRoute (Gateway API) Parameters

| Parameter               | Description                                            | Default |
| ----------------------- | ------------------------------------------------------ | ------- |
| `httpRoute.enabled`     | Enable Gateway API HTTPRoute                           | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                                  | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                                       | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments (required when enabled) | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                            | `[]`    |
| `httpRoute.rules`       | Route rules; `backendRefs` default to this service     | `[]`    |

### Storage & Scheduling

| Parameter             | Description                      | Default |
| --------------------- | -------------------------------- | ------- |
| `volumes`             | Additional volumes               | `[]`    |
| `volumeMounts`        | Additional volume mounts         | `[]`    |
| `resources`           | Resource requests and limits     | `{}`    |
| `nodeSelector`        | Node selector                    | `{}`    |
| `tolerations`         | Tolerations                      | `[]`    |
| `affinity`            | Affinity rules                   | `{}`    |
| `autoscaling.enabled` | Reserved; no template renders it | `false` |

## Examples

### Install on a Synology iSCSI cluster (default PVC matches)

```yaml
enabled: true

env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "100"
  - name: TZ
    value: "Europe/Paris"

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: overseer-config-iscsi-pvc   # provisioned by templates/pvc.yaml

volumeMounts:
  - name: config
    mountPath: /config

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: overseer.example.com
      paths:
        - path: /
          pathType: Prefix
```

### Install with a custom external PVC (different storage class)

The bundled PVC template is **always rendered** (it is not conditional) and is named `overseer-config-iscsi-pvc` with `storageClassName: synology-csi-iscsi-retain`. If your cluster doesn't have that class, you have two options:

1. Pre-create a PV with that exact `storageClassName` so the bundled PVC binds successfully, or
2. Bypass the bundled PVC by mounting your own claim with `volumes` and ignore the orphaned PVC (or post-render to delete it).

```yaml
enabled: true

env:
  - name: TZ
    value: "UTC"

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: my-overseer-config-pvc

volumeMounts:
  - name: config
    mountPath: /config
```

### Gateway API HTTPRoute

```yaml
enabled: true

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
  hostnames:
    - overseer.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: overseer-config-iscsi-pvc

volumeMounts:
  - name: config
    mountPath: /config
```

## Persistence

Overseerr writes all state to `/config`:

- `/config/db/db.sqlite3` — application database (users, requests, settings).
- `/config/settings.json` — server configuration written by the setup wizard.
- `/config/logs/` — application logs.

This chart ships a hardcoded `PersistentVolumeClaim` in `templates/pvc.yaml`:

- Name: `overseer-config-iscsi-pvc`
- Access mode: `ReadWriteOnce`
- Storage class: `synology-csi-iscsi-retain`
- Size: `5Gi`

The PVC template is unconditional — it will be created on every install. If you cannot satisfy that `StorageClass`, expect the PVC to stay `Pending`. The deployment itself does **not** auto-mount this PVC; you must reference it from `volumes` / `volumeMounts`. This decoupling is unusual — review the rendered manifests (`helm template overseer geekxflood/overseer`) before installing.

## Integration notes

Same as [`overseerr`](../overseerr): connect Plex via the setup wizard, then wire Sonarr / Radarr under **Settings -> Services**. Refer to that chart's README for full integration details.

## Upgrading

### To 0.4.0

- Documentation refresh; behaviour unchanged.

When upgrading Overseerr across major versions, back up `/config/db/db.sqlite3` first — schema migrations are forward-only.

## Uninstallation

```bash
helm uninstall overseer
```

The bundled PVC is **not** deleted by `helm uninstall` if it has `helm.sh/resource-policy: keep`, and even when it isn't, the underlying PV with `synology-csi-iscsi-retain` will retain the volume by design. Clean up manually:

```bash
kubectl delete pvc overseer-config-iscsi-pvc
```

## Support

- Overseerr docs: <https://docs.overseerr.dev>
- Overseerr source: <https://github.com/sct/overseerr>
- LinuxServer.io image: <https://hub.docker.com/r/linuxserver/overseerr>
- Chart Repository Issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. Overseerr is licensed under the [MIT License](https://github.com/sct/overseerr/blob/develop/LICENSE).

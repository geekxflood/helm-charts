# Huntarr Helm Chart

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A Helm chart for deploying [Huntarr](https://github.com/plexguide/huntarr.io) on Kubernetes. Huntarr is an automated missing-media finder that sits beside Sonarr, Radarr, and other *arr applications and periodically scans their libraries for missing or upgradeable items, then triggers searches without manual intervention.

## Overview

Huntarr fills a gap in the *arr stack: while Sonarr and Radarr know what is missing, they will not aggressively look for it forever. Huntarr keeps hunting on a schedule, walking through every library to find the gaps and trigger new search commands against your indexers via Prowlarr. This chart packages the upstream `huntarr/huntarr` image with a single web UI on port `9705`, a config PVC, and standard exposure options (Ingress, Gateway API HTTPRoute).

All of Huntarr's app-to-app wiring (Sonarr URL, Radarr URL, API keys, hunt thresholds, schedule) is performed inside the Huntarr web UI itself and persisted to the config volume. This chart does not template those values.

## Features

- Single-replica Deployment with `Recreate` strategy (config volume is RWO)
- HTTP `/health` liveness and readiness probes on port `9705`
- Persistent config volume via the chart-managed PVC (`persistence.enabled`)
- Ingress and vanilla Kubernetes Gateway API `HTTPRoute` exposure
- HorizontalPodAutoscaler support (off by default, not generally useful — Huntarr is single-instance)
- ServiceAccount with optional automount

## Prerequisites

- Kubernetes 1.19+ (Gateway API 1.0+ if using `httpRoute`)
- Helm 3.0+
- A working *arr stack (Sonarr/Radarr/Prowlarr) reachable from the cluster — Huntarr only adds value when paired with these
- Persistent storage for `/config` (recommended) so configured connections and run history survive restarts

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install huntarr geekxflood/huntarr -f values.yaml
```

The chart ships with `enabled: false`. You must override this to render any resources.

## Configuration

### Core Parameters

| Parameter          | Description                                              | Default           |
| ------------------ | -------------------------------------------------------- | ----------------- |
| `enabled`          | Master switch — must be `true` to render resources       | `false`           |
| `replicaCount`     | Pod replicas (keep at `1`; Huntarr is not HA-safe)       | `1`               |
| `image.repository` | Container image                                          | `huntarr/huntarr` |
| `image.tag`        | Image tag                                                | `latest`          |
| `image.pullPolicy` | Image pull policy                                        | `Always`          |
| `imagePullSecrets` | Image pull secret references                             | `[]`              |
| `nameOverride`     | Override the chart name component of resource names      | `""`              |
| `fullnameOverride` | Override the full release name component                 | `""`              |

### Service Account

| Parameter                    | Description                     | Default |
| ---------------------------- | ------------------------------- | ------- |
| `serviceAccount.create`      | Create a ServiceAccount         | `true`  |
| `serviceAccount.automount`   | Automount the token             | `true`  |
| `serviceAccount.annotations` | Annotations on the SA           | `{}`    |
| `serviceAccount.name`        | Use an existing SA name         | `""`    |

### Pod & Container

| Parameter            | Description                | Default |
| -------------------- | -------------------------- | ------- |
| `podAnnotations`     | Pod annotations            | `{}`    |
| `podLabels`          | Pod labels                 | `{}`    |
| `podSecurityContext` | Pod-level security context | `{}`    |
| `securityContext`    | Container security context | `{}`    |
| `env`                | Environment variable list  | `[]`    |
| `resources`          | Resource requests/limits   | `{}`    |
| `nodeSelector`       | Node selector              | `{}`    |
| `tolerations`        | Pod tolerations            | `[]`    |
| `affinity`           | Pod affinity rules         | `{}`    |
| `strategy.type`      | Deployment strategy        | `Recreate` |

### Service

| Parameter      | Description       | Default     |
| -------------- | ----------------- | ----------- |
| `service.type` | Kubernetes Service type | `ClusterIP` |
| `service.port` | Service port (Huntarr web UI) | `9705`      |

### Ingress

| Parameter             | Description           | Default |
| --------------------- | --------------------- | ------- |
| `ingress.enabled`     | Create an Ingress     | `false` |
| `ingress.className`   | IngressClass name     | `""`    |
| `ingress.annotations` | Ingress annotations   | `{}`    |
| `ingress.hosts`       | Host/path definitions | `[]`    |
| `ingress.tls`         | TLS host/secret pairs | `[]`    |

### Gateway API HTTPRoute

| Parameter               | Description                              | Default |
| ----------------------- | ---------------------------------------- | ------- |
| `httpRoute.enabled`     | Create a Gateway API `HTTPRoute`         | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                    | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                         | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments           | `[]`    |
| `httpRoute.hostnames`   | Matched hostnames                        | `[]`    |
| `httpRoute.rules`       | Route rules; `backendRefs` defaults to this chart's Service on `service.port` when omitted | `[]`    |

### Persistence

| Parameter                | Description                                                                | Default          |
| ------------------------ | -------------------------------------------------------------------------- | ---------------- |
| `persistence.enabled`    | Create a chart-managed PVC for `/config`                                   | `false`          |
| `persistence.name`       | Override PVC name (default `<release>-config-pvc`)                         | `""`             |
| `persistence.storageClass` | StorageClass for the PVC                                                 | `""` (cluster default) |
| `persistence.accessMode` | PVC access mode                                                            | `ReadWriteOnce`  |
| `persistence.size`       | PVC size                                                                   | `1Gi`            |
| `persistence.volumeName` | Bind to a specific PV (for migration / data recovery)                      | `""`             |
| `volumes`                | Extra pod volumes (used when you bring your own PVC instead of `persistence`) | `[]`             |
| `volumeMounts`           | Extra container mounts                                                     | `[]`             |

Note: the chart's PVC at `persistence.enabled=true` is **not** automatically mounted into the pod. You must add a matching entry to `volumes` and `volumeMounts` (see the example below) — this gives you control over the in-container mount path.

### Probes & Autoscaling

| Parameter                  | Description                                | Default               |
| -------------------------- | ------------------------------------------ | --------------------- |
| `livenessProbe`            | HTTP GET `/health` on port 9705            | 40s delay, 30s period |
| `readinessProbe`           | HTTP GET `/health` on port 9705            | 20s delay, 15s period |
| `autoscaling.enabled`      | Enable HPA (not recommended for Huntarr)   | `false`               |
| `autoscaling.minReplicas`  | HPA min replicas                           | `1`                   |
| `autoscaling.maxReplicas`  | HPA max replicas                           | `100`                 |

## Examples

### Minimal install with config persistence and Ingress

```yaml
enabled: true

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: huntarr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: huntarr-tls
      hosts:
        - huntarr.example.com

persistence:
  enabled: true
  size: 2Gi
  storageClass: longhorn

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: huntarr-config-pvc

volumeMounts:
  - name: config
    mountPath: /config

env:
  - name: TZ
    value: "Europe/Paris"
```

### Gateway API exposure (Cilium / Istio / Envoy Gateway)

```yaml
enabled: true

ingress:
  enabled: false

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - huntarr.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1

persistence:
  enabled: true
  size: 2Gi

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: huntarr-config-pvc
volumeMounts:
  - name: config
    mountPath: /config
```

Cilium operators: `parentRefs[*].port` is ignored — use `sectionName` to target a listener. Cross-namespace `backendRefs` require a `ReferenceGrant`.

## Persistence

Huntarr stores its configuration, hunt history, and credentials at `/config` inside the container. Two patterns are supported:

1. **Chart-managed PVC** — set `persistence.enabled: true`, then add a matching entry to `volumes`/`volumeMounts` to bind the claim to `/config`. The PVC name defaults to `<release>-config-pvc` and can be overridden with `persistence.name`.
2. **Bring your own PVC** — leave `persistence.enabled: false` and provide your own PVC via `volumes`/`volumeMounts`.

Use `ReadWriteOnce` and the `Recreate` deployment strategy (default) to avoid two pods racing for the same volume during rollouts.

## Integration notes

Huntarr does not need any chart-level configuration to talk to your *arr apps — everything happens inside its web UI. After installing:

1. Port-forward or browse to the Service (`kubectl port-forward svc/<release>-huntarr 9705:9705`) and complete the first-run wizard.
2. Add each Sonarr/Radarr/Lidarr/Readarr instance using its in-cluster DNS name, for example:
   - Radarr: `http://radarr.media.svc.cluster.local:7878`
   - Sonarr: `http://sonarr.media.svc.cluster.local:8989`
3. Paste each app's API key (found under *Settings → General* in the *arr UI).
4. Tune the hunt schedule, hourly cap, and "missing" / "upgrade" thresholds per app.

Because Huntarr triggers search commands against your indexers, it benefits directly from a well-tuned Prowlarr install. Expect a flurry of indexer activity on the first run.

## Upgrading

This chart is at `0.2.0`. There are no documented breaking changes from `0.1.x`. When bumping the `appVersion`, review the upstream [Huntarr release notes](https://github.com/plexguide/huntarr.io/releases) for migration steps.

## Support

- Upstream Huntarr: [github.com/plexguide/huntarr.io](https://github.com/plexguide/huntarr.io)
- Chart issues: [github.com/geekxflood/helm-charts/issues](https://github.com/geekxflood/helm-charts/issues)

## License

This Helm chart is licensed under the Apache License 2.0. Huntarr is distributed under its own license; consult the upstream repository for details.

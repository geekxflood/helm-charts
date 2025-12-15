# Seerr Helm Chart

Open-source media request and discovery manager for Jellyfin, Plex, and Emby.

## Disclaimer

This helm chart is not an official Seerr Team release. It is maintained by the Geekxflood team and is not affiliated with or endorsed by the Seerr Team.

For official Seerr helm charts or support, please refer to the [Seerr Team Documentation](https://docs.seerr.dev/getting-started/kubernetes).

Many thanks to the Seerr development team for creating and maintaining this excellent software!

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installing the Chart](#installing-the-chart)
- [Uninstalling the Chart](#uninstalling-the-chart)
- [Parameters](#parameters)
  - [Common Parameters](#common-parameters)
  - [Image Parameters](#image-parameters)
  - [Service Parameters](#service-parameters)
  - [Ingress Parameters](#ingress-parameters)
  - [Persistence Parameters](#persistence-parameters)
  - [Environment Variables](#environment-variables)
  - [Cloudflare Tunnel Parameters](#cloudflare-tunnel-parameters)
  - [Resource Parameters](#resource-parameters)
  - [Security Parameters](#security-parameters)
  - [Scheduling Parameters](#scheduling-parameters)
  - [Deployment Strategy](#deployment-strategy)
- [Configuration Examples](#configuration-examples)
- [Important Notes](#important-notes)
- [Upgrading](#upgrading)
- [Troubleshooting](#troubleshooting)
- [Common Issues](#common-issues)
- [Support](#support)

## Introduction

This Helm chart deploys [Seerr](https://github.com/seerr-team/seerr) on a Kubernetes cluster. Seerr is a free and open-source software application for managing requests for your media library. It integrates with Jellyfin, Plex, and Emby media servers, as well as Sonarr and Radarr for automated media management.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PV provisioner support in the underlying infrastructure (if persistence is enabled)

## Quick Start

```bash
# Install with default values (disabled by default)
helm install seerr ./charts/seerr

# Install with custom values
helm install seerr ./charts/seerr -f my-values.yaml

# Install with inline values
helm install seerr ./charts/seerr --set enabled=true --set persistence.enabled=true

# Upgrade existing installation
helm upgrade seerr ./charts/seerr -f my-values.yaml

# Uninstall
helm uninstall seerr
```

## Installing the Chart

To install the chart with the release name `seerr`:

```bash
helm install seerr ./charts/seerr -f values.yaml
```

**Note:** The chart is disabled by default (`enabled: false`). You must set `enabled: true` in your values file or via `--set enabled=true`.

The command deploys Seerr on the Kubernetes cluster with default configuration. The [Parameters](#parameters) section lists the parameters that can be configured during installation.

## Uninstalling the Chart

To uninstall/delete the `seerr` deployment:

```bash
helm uninstall seerr
```

**Warning:** This will not delete the PersistentVolumeClaim by default. To delete it:

```bash
kubectl delete pvc <pvc-name>
```

## Parameters

### Common Parameters

| Parameter          | Description                         | Default |
| ------------------ | ----------------------------------- | ------- |
| `enabled`          | Enable/disable the chart deployment | `false` |
| `replicaCount`     | Number of Seerr replicas            | `1`     |
| `nameOverride`     | Override the chart name             | `""`    |
| `fullnameOverride` | Override the full chart name        | `""`    |

### Image Parameters

| Parameter          | Description                              | Default            |
| ------------------ | ---------------------------------------- | ------------------ |
| `image.registry`   | Container registry                       | `ghcr.io`          |
| `image.repository` | Image repository path                    | `seerr-team/seerr` |
| `image.pullPolicy` | Image pull policy                        | `Always`           |
| `image.tag`        | Image tag (defaults to Chart appVersion) | `develop`          |
| `imagePullSecrets` | Image pull secrets                       | `[]`               |

### Service Parameters

| Parameter      | Description             | Default     |
| -------------- | ----------------------- | ----------- |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port            | `5055`      |

### Ingress Parameters

| Parameter             | Description                        | Default         |
| --------------------- | ---------------------------------- | --------------- |
| `ingress.enabled`     | Enable ingress controller resource | `false`         |
| `ingress.className`   | Ingress class name                 | `""`            |
| `ingress.annotations` | Ingress annotations                | `{}`            |
| `ingress.hosts`       | Ingress hosts configuration        | See values.yaml |
| `ingress.tls`         | Ingress TLS configuration          | `[]`            |

### Persistence Parameters

| Parameter                  | Description                  | Default               |
| -------------------------- | ---------------------------- | --------------------- |
| `persistence.enabled`      | Enable persistence using PVC | `false`               |
| `persistence.name`         | PVC name                     | `""` (auto-generated) |
| `persistence.storageClass` | Storage class for PVC        | `""`                  |
| `persistence.accessMode`   | PVC access mode              | `ReadWriteOnce`       |
| `persistence.size`         | PVC size                     | `10Gi`                |
| `persistence.volumeName`   | Bind to specific PV          | `""`                  |
| `persistence.mountPath`    | Mount path for config data   | `/app/config`         |

### Environment Variables

| Parameter | Description                                   | Default |
| --------- | --------------------------------------------- | ------- |
| `env`     | Environment variables as list                 | `[]`    |
| `envFrom` | Environment variables from secrets/configmaps | `[]`    |

Example:

```yaml
env:
  - name: TZ
    value: "America/New_York"
  - name: LOG_LEVEL
    value: "info"
```

### Cloudflare Tunnel Parameters

| Parameter            | Description                          | Default |
| -------------------- | ------------------------------------ | ------- |
| `cfTunnel.enabled`   | Enable Cloudflare Tunnel integration | `false` |
| `cfTunnel.tunnelRef` | Tunnel reference configuration       | `{}`    |
| `cfTunnel.subjects`  | Tunnel subjects configuration        | `[]`    |

### Resource Parameters

| Parameter            | Description       | Default |
| -------------------- | ----------------- | ------- |
| `resources.limits`   | Resource limits   | `{}`    |
| `resources.requests` | Resource requests | `{}`    |

### Security Parameters

| Parameter                    | Description                 | Default |
| ---------------------------- | --------------------------- | ------- |
| `podSecurityContext`         | Pod security context        | `{}`    |
| `securityContext`            | Container security context  | `{}`    |
| `serviceAccount.create`      | Create service account      | `true`  |
| `serviceAccount.annotations` | Service account annotations | `{}`    |
| `serviceAccount.name`        | Service account name        | `""`    |

### Scheduling Parameters

| Parameter      | Description                       | Default |
| -------------- | --------------------------------- | ------- |
| `nodeSelector` | Node labels for pod assignment    | `{}`    |
| `tolerations`  | Tolerations for pod assignment    | `[]`    |
| `affinity`     | Affinity rules for pod assignment | `{}`    |

### Deployment Strategy

| Parameter       | Description              | Default    |
| --------------- | ------------------------ | ---------- |
| `strategy.type` | Deployment strategy type | `Recreate` |

## Configuration Examples

### Basic Installation with Persistence

```yaml
enabled: true

persistence:
  enabled: true
  size: 20Gi
  storageClass: "fast-ssd"
  # IMPORTANT: Bind to specific PV to prevent data loss on PVC recreation
  # Get PV name: kubectl get pvc <pvc-name> -o jsonpath='{.spec.volumeName}'
  volumeName: "pv-seerr-config"
```

### Installation with Ingress

```yaml
enabled: true

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
  hosts:
    - host: seerr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: seerr-tls
      hosts:
        - seerr.example.com

persistence:
  enabled: true
  size: 10Gi
```

### Installation with Cloudflare Tunnel

```yaml
enabled: true

cfTunnel:
  enabled: true
  tunnelRef:
    kind: ClusterTunnel
    name: my-tunnel
  subjects:
    - name: seerr
      spec:
        fqdn: seerr.example.com

persistence:
  enabled: true
  size: 10Gi
```

### Installation with Environment Variables

```yaml
enabled: true

env:
  - name: TZ
    value: "America/New_York"
  - name: LOG_LEVEL
    value: "debug"
  - name: PORT
    value: "5055"

# Or use secrets/configmaps
envFrom:
  - type: secret
    name: seerr-secrets
  - type: configmap
    name: seerr-config

persistence:
  enabled: true
  size: 10Gi
```

### Installation with Resource Limits

```yaml
enabled: true

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

persistence:
  enabled: true
  size: 10Gi
```

### Installation with Custom Image Registry

```yaml
enabled: true

image:
  registry: "my-registry.example.com"
  repository: "seerr-team/seerr"
  tag: "latest"
  pullPolicy: IfNotPresent

imagePullSecrets:
  - name: my-registry-secret

persistence:
  enabled: true
  size: 10Gi
```

### Production Installation (Complete Example)

```yaml
enabled: true

replicaCount: 1

image:
  registry: "ghcr.io"
  repository: "seerr-team/seerr"
  tag: "develop"
  pullPolicy: Always

env:
  - name: TZ
    value: "America/New_York"
  - name: LOG_LEVEL
    value: "info"

persistence:
  enabled: true
  size: 50Gi
  storageClass: "fast-ssd"
  volumeName: "pv-seerr-config-prod"
  accessMode: ReadWriteOnce

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  hosts:
    - host: seerr.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: seerr-tls
      hosts:
        - seerr.example.com

resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 512Mi

strategy:
  type: Recreate

nodeSelector:
  disktype: ssd

podSecurityContext:
  fsGroup: 1000
  runAsUser: 1000
  runAsNonRoot: true

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL
```

## Important Notes

### Persistence Configuration

- **Always use `volumeName`** in production to bind the PVC to a specific PersistentVolume. This prevents data loss if the PVC is accidentally deleted and recreated.
- Get the current PV name with: `kubectl get pvc <pvc-name> -o jsonpath='{.spec.volumeName}'`
- The default mount path is `/app/config` where Seerr stores its configuration and database.

### Deployment Strategy Configuration

- The chart uses `Recreate` strategy by default, which is recommended for applications using ReadWriteOnce (RWO) volumes.
- This ensures the old pod is terminated before the new one starts, preventing volume attachment conflicts.

### Image Registry Configuration

- The image is split into `registry` and `repository` for better flexibility.
- Full image path is constructed as: `{registry}/{repository}:{tag}`
- Default: `ghcr.io/seerr-team/seerr:develop`

### Environment Variable Configuration

- Use the `env` array for simple key-value pairs.
- Use `envFrom` to load environment variables from Secrets or ConfigMaps.
- Supported `envFrom` types: `secret` and `configmap`.

## Upgrading

To upgrade the Seerr deployment:

```bash
helm upgrade seerr ./charts/seerr -f your-values.yaml
```

### Upgrade Notes

- Always backup your persistent volume before upgrading.
- Review the changelog for breaking changes.
- Test upgrades in a non-production environment first.

## Troubleshooting

### Pod Not Starting

Check pod status and logs:

```bash
kubectl get pods -l app.kubernetes.io/name=seerr
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Persistence Issues

If the pod can't mount the volume:

```bash
# Check PVC status
kubectl get pvc

# Check PV binding
kubectl get pv

# Verify volumeName matches
kubectl get pvc <pvc-name> -o yaml | grep volumeName
```

### Ingress Not Working

Verify ingress configuration:

```bash
kubectl get ingress
kubectl describe ingress <ingress-name>

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Cloudflare Tunnel Issues

Check tunnel binding status:

```bash
kubectl get tunnelbinding
kubectl describe tunnelbinding <binding-name>
```

## Common Issues

### "Volume is already attached to another pod"

This happens when using RWO volumes and the old pod hasn't terminated yet. The `Recreate` strategy should prevent this, but if it occurs:

```bash
# Force delete the old pod
kubectl delete pod <pod-name> --force --grace-period=0
```

### Configuration Not Persisting

Ensure persistence is enabled and the PVC is bound:

```bash
kubectl get pvc
# Status should be "Bound"
```

### Cannot Access Seerr UI

1. Check if the pod is running: `kubectl get pods`
2. Check service: `kubectl get svc`
3. Port-forward to test: `kubectl port-forward svc/<service-name> 5055:5055`
4. Access at: `http://localhost:5055`

## Support

### Official Seerr Support

- Documentation: <https://docs.seerr.dev>
- GitHub: <https://github.com/seerr-team/seerr>
- Discord: <https://discord.gg/seerr>

### Helm Chart Support

- Chart Issues: <https://github.com/geekxflood/helm-charts/issues>
- Chart Maintainer: geekxflood

## License

This Helm chart is provided as-is under the MIT License. Seerr itself is licensed under the MIT License.

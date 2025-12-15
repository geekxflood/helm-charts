# Jellyfin Helm Chart

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 10.10.3](https://img.shields.io/badge/AppVersion-10.10.3-informational?style=flat-square)

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
| `image.tag`        | Image tag                 | `"10.10.3"`            |
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

### Environment Variables

| Parameter | Description                                 | Default |
| --------- | ------------------------------------------- | ------- |
| `env`     | Environment variables array                 | `[]`    |
| `envFrom` | Environment variables from ConfigMap/Secret | `[]`    |

### Runtime Parameters

| Parameter         | Description          | Default |
| ----------------- | -------------------- | ------- |
| `runtime.enabled` | Enable runtime class | `false` |
| `runtime.name`    | Runtime class name   | `""`    |

### Service Parameters

| Parameter      | Description  | Default     |
| -------------- | ------------ | ----------- |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `9091`      |

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
| `cfTunnel.subjects`  | Tunnel subjects          | `{}`    |

### Resource Management

| Parameter   | Description                  | Default |
| ----------- | ---------------------------- | ------- |
| `resources` | Resource requests and limits | `{}`    |

### Autoscaling Parameters

| Parameter                                       | Description                      | Default |
| ----------------------------------------------- | -------------------------------- | ------- |
| `autoscaling.enabled`                           | Enable horizontal pod autoscaler | `false` |
| `autoscaling.minReplicas`                       | Minimum replicas                 | `1`     |
| `autoscaling.maxReplicas`                       | Maximum replicas                 | `100`   |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU utilization           | `80`    |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization        | `80`    |

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

### Installation with Resource Limits

```yaml
enabled: true

resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "2000m"

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: jellyfin-config
```

### Installation with GPU Support

```yaml
enabled: true

runtime:
  enabled: true
  name: nvidia

resources:
  limits:
    nvidia.com/gpu: 1

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: jellyfin-config
  - name: media
    hostPath:
      path: /mnt/media
```

## Persistence

Jellyfin requires persistent storage for:

1. **Configuration data** (`/config`): Stores server configuration, metadata, and database
2. **Media files** (`/media`): Your media library (videos, music, photos)

It is strongly recommended to use PersistentVolumeClaims for both directories in production environments.

## Upgrading

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

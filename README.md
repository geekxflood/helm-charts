# Media-Stack

<p align="center" width="100%">
    <img width="33%" src="assets/icon.png">
</p>

This Helm chart is a comprehensive package for deploying a full media stack on Kubernetes. It includes popular applications such as Sonarr, Radarr, Prowlarr, Transmission, Overseerr, and Plex.

## Table of Contents

- [Media-Stack](#media-stack)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Usage](#usage)
    - [Add Helm Repository](#add-helm-repository)
    - [Install Chart](#install-chart)
    - [Uninstall Chart](#uninstall-chart)
  - [Applications](#applications)
    - [Bazarr](#bazarr)
      - [Values](#values)
    - [DizqueTV](#dizquetv)
      - [Values](#values-1)
    - [Flaresolverr](#flaresolverr)
      - [Values](#values-2)
    - [Jellyfin](#jellyfin)
      - [Values](#values-3)
    - [Overseerr](#overseerr)
      - [Values](#values-4)
    - [Plex](#plex)
      - [Values](#values-5)
    - [Prowlarr](#prowlarr)
      - [Values](#values-6)
    - [Radarr](#radarr)
      - [Values](#values-7)
    - [Sonarr](#sonarr)
      - [Values](#values-8)
    - [Tautulli](#tautulli)
      - [Values](#values-9)
    - [Tautulli Exporter](#tautulli-exporter)
      - [Values](#values-10)
    - [Transmission](#transmission)
      - [Values](#values-11)
  - [Specialties](#specialties)
  - [License](#license)

## Prerequisites

- Kubernetes 1.12+
- Helm 3.0+

## Usage

### Add Helm Repository

To add the repository to your Helm client:

```shell
helm repo add media-stack https://geekxflood.github.io/media-stack
```

If you've previously added this repo, run the following command to update to the latest versions of the packages:

```shell
helm repo update
```

To see the available charts in the repo:

```shell
helm search repo media-stack
```

### Install Chart

To install the media-stack chart with the release name my-media-stack:

```shell
helm install my-media-stack media-stack/media-stack
```

Customize the installation by modifying the `values.yaml` file or using the --set flag with installation commands.

### Uninstall Chart

To uninstall the my-media-stack deployment:

```shell
helm delete my-media-stack
```

## Applications

Each application included in the Media-Stack is designed to enhance your media experience, from content management to streaming. Below is a detailed description of each application:

### Bazarr

[Bazarr](https://www.bazarr.media/) is a powerful tool for managing and automatically downloading subtitles. It works in tandem with Sonarr and Radarr to find subtitles in multiple languages for TV shows and movies.

#### Values

| Value Name | Description | Structure/Default |
|------------|-------------|-------------------|
| `.enabled` | Enable or disable the Bazarr service | Boolean: `false` |
| `.replicaCount` | Number of replicas for Bazarr | Integer: `1` |
| `.image.repository` | Docker image repository for Bazarr | String: `"linuxserver/bazarr"` |
| `.image.pullPolicy` | Image pull policy for Bazarr | String: `"IfNotPresent"` |
| `.image.tag` | Docker image tag for Bazarr | String: `""` (empty string) |
| `.imagePullSecrets` | Specify image pull secrets | Array: `[]` (empty array) |
| `.nameOverride` | Override the app name | String: `""` (empty string) |
| `.fullnameOverride` | Override the full name of the app | String: `""` (empty string) |
| `.env` | Environment variables for Bazarr | Array: `[]` (empty array) |
| `.serviceAccount.create` | Specifies whether a service account should be created | Boolean: `true` |
| `.serviceAccount.automount` | Automount service account token | Boolean: `true` |
| `.serviceAccount.annotations` | Annotations to add to the service account | Object: `{}` (empty object) |
| `.serviceAccount.name` | The name of the service account to use | String: `""` (empty string) |
| `.podAnnotations` | Annotations to add to the pod | Object: `{}` (empty object) |
| `.podLabels` | Labels to add to the pod | Object: `{}` (empty object) |
| `.podSecurityContext` | Security context policies for the pod | Object: `{}` (empty object) |
| `.securityContext` | Security context policies for the container | Object: `{}` (empty object) |
| `.service.type` | Service type for Bazarr | String: `"ClusterIP"` |
| `.service.port` | Port number for Bazarr service | Integer: `6767` |
| `.ingress.enabled` | Enable or disable ingress | Boolean: `false` |
| `.ingress.className` | Ingress class name | String: `""` (empty string) |
| `.ingress.annotations` | Annotations for the ingress | Object: `{}` (empty object) |
| `.ingress.hosts` | Hosts configuration for the ingress | Array: `[]` (empty array) |
| `.ingress.tls` | TLS configuration for the ingress | Array: `[]` (empty array) |
| `.resources` | CPU/Memory resource requests/limits | Object: `{}` (empty object) |
| `.autoscaling.enabled` | Enable or disable autoscaling | Boolean: `false` |
| `.autoscaling.minReplicas` | Minimum number of replicas | Integer: `1` |
| `.autoscaling.maxReplicas` | Maximum number of replicas | Integer: `100` |
| `.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | Integer: `80` |
| `.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | Integer: `80` |
| `.volumes` | Custom volumes for Bazarr | Array: `[]` (empty array) |
| `.volumeMounts` | Mount paths for custom volumes | Array: `[]` (empty array) |
| `.nodeSelector` | Node labels for pod assignment | Object: `{}` (empty object) |
| `.tolerations` | Tolerations for pod assignment | Array: `[]` (empty array) |
| `.affinity` | Affinity settings for pod assignment | Object: `{}` (empty object) |


### DizqueTV

[DizqueTV](https://github.com/vexorian/dizquetv) allows the creation of custom TV channels from Plex libraries. It simulates the experience of broadcast TV, providing a unique way to enjoy your Plex content.

#### Values

| Value Name | Description | Structure/Default |
|------------|-------------|-------------------|
| `.enabled` | Enable or disable the dizqueTV service | Boolean: `false` |
| `.replicaCount` | Number of replicas for dizqueTV | Integer: `1` |
| `.image.repository` | Docker image repository for dizqueTV | String: `"vexorian/dizquetv"` |
| `.image.pullPolicy` | Image pull policy for dizqueTV | String: `"IfNotPresent"` |
| `.image.tag` | Docker image tag for dizqueTV | String: `""` (empty string) |
| `.imagePullSecrets` | Specify image pull secrets | Array: `[]` (empty array) |
| `.nameOverride` | Override the app name | String: `""` (empty string) |
| `.fullnameOverride` | Override the full name of the app | String: `""` (empty string) |
| `.serviceAccount.create` | Specifies whether a service account should be created | Boolean: `true` |
| `.serviceAccount.automount` | Automount service account token | Boolean: `true` |
| `.serviceAccount.annotations` | Annotations to add to the service account | Object: `{}` (empty object) |
| `.serviceAccount.name` | The name of the service account to use | String: `""` (empty string) |
| `.podAnnotations` | Annotations to add to the pod | Object: `{}` (empty object) |
| `.podLabels` | Labels to add to the pod | Object: `{}` (empty object) |
| `.podSecurityContext` | Security context policies for the pod | Object: `{}` (empty object) |
| `.securityContext` | Security context policies for the container | Object: `{}` (empty object) |
| `.env` | Environment variables for dizqueTV | Array: `[]` (empty array) |
| `.runtime.nvidia.enabled` | Enable NVIDIA GPU support | Boolean: `false` |
| `.resources` | CPU/Memory resource requests/limits | Object: `{}` (empty object) |
| `.autoscaling.enabled` | Enable or disable autoscaling | Boolean: `false` |
| `.autoscaling.minReplicas` | Minimum number of replicas | Integer: `1` |
| `.autoscaling.maxReplicas` | Maximum number of replicas | Integer: `100` |
| `.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | Integer: `80` |
| `.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | Integer: `80` |
| `.volumes` | Custom volumes for dizqueTV | Array: `[]` (empty array) |
| `.volumeMounts` | Mount paths for custom volumes | Array: `[]` (empty array) |
| `.nodeSelector` | Node labels for pod assignment | Object: `{}` (empty object) |
| `.tolerations` | Tolerations for pod assignment | Array: `[]` (empty array) |
| `.affinity` | Affinity settings for pod assignment | Object: `{}` (empty object) |

### Flaresolverr

[Flaresolverr](https://github.com/FlareSolverr/FlareSolverr) acts as a proxy server to help bypass Cloudflare's anti-bot measures. It's essential for applications that scrape web content, ensuring smooth access to various media sources.

#### Values

| Value Name | Description | Structure/Default |
|------------|-------------|-------------------|
| `.enabled` | Enable or disable the Flaresolverr service | Boolean: `false` |
| `.replicaCount` | Number of replicas for Flaresolverr | Integer: `1` |
| `.image.repository` | Docker image repository for Flaresolverr | String: `"ghcr.io/flaresolverr/flaresolverr"` |
| `.image.pullPolicy` | Image pull policy for Flaresolverr | String: `"IfNotPresent"` |
| `.image.tag` | Docker image tag for Flaresolverr | String: `""` (empty string) |
| `.imagePullSecrets` | Specify image pull secrets | Array: `[]` (empty array) |
| `.nameOverride` | Override the app name | String: `""` (empty string) |
| `.fullnameOverride` | Override the full name of the app | String: `""` (empty string) |
| `.serviceAccount.create` | Specifies whether a service account should be created | Boolean: `true` |
| `.serviceAccount.automount` | Automount service account token | Boolean: `true` |
| `.serviceAccount.annotations` | Annotations to add to the service account | Object: `{}` (empty object) |
| `.serviceAccount.name` | The name of the service account to use | String: `""` (empty string) |
| `.podAnnotations` | Annotations to add to the pod | Object: `{}` (empty object) |
| `.podLabels` | Labels to add to the pod | Object: `{}` (empty object) |
| `.podSecurityContext` | Security context policies for the pod | Object: `{}` (empty object) |
| `.securityContext` | Security context policies for the container | Object: `{}` (empty object) |
| `.env` | Environment variables for Flaresolverr | Array: `[]` (empty array) |
| `.service.type` | Service type for Flaresolverr | String: `"ClusterIP"` |
| `.service.port` | Port number for Flaresolverr service | Integer: `8191` |
| `.ingress.enabled` | Enable or disable ingress | Boolean: `false` |
| `.ingress.className` | Ingress class name | String: `""` (empty string) |
| `.ingress.annotations` | Annotations for the ingress | Object: `{}` (empty object) |
| `.ingress.hosts` | Hosts configuration for the ingress | Array: `[]` (empty array) |
| `.ingress.tls` | TLS configuration for the ingress | Array: `[]` (empty array) |
| `.resources` | CPU/Memory resource requests/limits | Object: `{}` (empty object) |
| `.autoscaling.enabled` | Enable or disable autoscaling | Boolean: `false` |
| `.autoscaling.minReplicas` | Minimum number of replicas | Integer: `1` |
| `.autoscaling.maxReplicas` | Maximum number of replicas | Integer: `100` |
| `.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | Integer: `80` |
| `.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | Integer: `80` |
| `.volumes` | Custom volumes for Flaresolverr | Array: `[]` (empty array) |
| `.volumeMounts` | Mount paths for custom volumes | Array: `[]` (empty array) |
| `.nodeSelector` | Node labels for pod assignment | Object: `{}` (empty object) |
| `.tolerations` | Tolerations for pod assignment | Array: `[]` (empty array) |
| `.affinity` | Affinity settings for pod assignment | Object: `{}` (empty object) |

### Jellyfin

[Jellyfin](https://jellyfin.org/) offers a personal media server experience, putting you in complete control. It's an open-source alternative to Plex, allowing you to organize and stream media to any device from your server.

#### Values

| Value Name | Description | Structure/Default |
|------------|-------------|-------------------|
| `.enabled` | Enable or disable the Jellyfin service | Boolean: `false` |
| `.replicaCount` | Number of replicas for Jellyfin | Integer: `1` |
| `.image.repository` | Docker image repository for Jellyfin | String: `"linuxserver/jellyfin"` |
| `.image.pullPolicy` | Image pull policy for Jellyfin | String: `"IfNotPresent"` |
| `.image.tag` | Docker image tag for Jellyfin | String: `""` (empty string) |
| `.imagePullSecrets` | Specify image pull secrets | Array: `[]` (empty array) |
| `.nameOverride` | Override the app name | String: `""` (empty string) |
| `.fullnameOverride` | Override the full name of the app | String: `""` (empty string) |
| `.serviceAccount.create` | Specifies whether a service account should be created | Boolean: `true` |
| `.serviceAccount.automount` | Automount service account token | Boolean: `true` |
| `.serviceAccount.annotations` | Annotations to add to the service account | Object: `{}` (empty object) |
| `.serviceAccount.name` | The name of the service account to use | String: `""` (empty string) |
| `.podAnnotations` | Annotations to add to the pod | Object: `{}` (empty object) |
| `.podLabels` | Labels to add to the pod | Object: `{}` (empty object) |
| `.podSecurityContext` | Security context policies for the pod | Object: `{}` (empty object) |
| `.securityContext.capabilities.add` | Security capabilities to add for Jellyfin | Array: `["NET_ADMIN"]` |
| `.env` | Environment variables for Jellyfin | Array: `[]` (empty array) |
| `.service.type` | Service type for Jellyfin | String: `"ClusterIP"` |
| `.service.port` | Port number for Jellyfin service | Integer: `9091` |
| `.ingress.enabled` | Enable or disable ingress | Boolean: `false` |
| `.ingress.className` | Ingress class name | String: `""` (empty string) |
| `.ingress.annotations` | Annotations for the ingress | Object: `{}` (empty object) |
| `.ingress.hosts` | Hosts configuration for the ingress | Array: `[]` (empty array) |
| `.ingress.tls` | TLS configuration for the ingress | Array: `[]` (empty array) |
| `.cfTunnel.enabled` | Enable or disable Cloudflare Tunnel | Boolean: `false` |
| `.cfTunnel.fqdn` | FQDN for Cloudflare Tunnel | String: `""` (empty string) |
| `.cfTunnel.tunnelName` | Name of the Cloudflare Tunnel | String: `""` (empty string) |
| `.runtime.nvidia.enabled` | Enable NVIDIA GPU support | Boolean: `false` |
| `.resources` | CPU/Memory resource requests/limits | Object: `{}` (empty object) |
| `.autoscaling.enabled` | Enable or disable autoscaling | Boolean: `false` |
| `.autoscaling.minReplicas` | Minimum number of replicas | Integer: `1` |
| `.autoscaling.maxReplicas` | Maximum number of replicas | Integer: `100` |
| `.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | Integer: `80` |
| `.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | Integer: `80` |
| `.volumes` | Custom volumes for Jellyfin | Array: `[]` (empty array) |
| `.volumeMounts` | Mount paths for custom volumes | Array: `[]` (empty array) |
| `.nodeSelector` | Node labels for pod assignment | Object: `{}` (empty object) |
| `.tolerations` | Tolerations for pod assignment | Array: `[]` (empty array) |
| `.affinity` | Affinity settings for pod assignment | Object: `{}` (empty object) |

### Overseerr

[Overseerr](https://overseerr.dev/) is a user-friendly request management system. It integrates seamlessly with Plex, providing an efficient way to discover and request new media.

#### Values

| Value Name | Description | Structure/Default |
|------------|-------------|-------------------|
| `.enabled` | Enable or disable the Overseerr service | Boolean: `false` |
| `.replicaCount` | Number of replicas for Overseerr | Integer: `1` |
| `.image.repository` | Docker image repository for Overseerr | String: `"linuxserver/overseerr"` |
| `.image.pullPolicy` | Image pull policy for Overseerr | String: `"IfNotPresent"` |
| `.image.tag` | Docker image tag for Overseerr | String: `""` (empty string) |
| `.imagePullSecrets` | Specify image pull secrets | Array: `[]` (empty array) |
| `.nameOverride` | Override the app name | String: `""` (empty string) |
| `.fullnameOverride` | Override the full name of the app | String: `""` (empty string) |
| `.serviceAccount.create` | Specifies whether a service account should be created | Boolean: `true` |
| `.serviceAccount.automount` | Automount service account token | Boolean: `true` |
| `.serviceAccount.annotations` | Annotations to add to the service account | Object: `{}` (empty object) |
| `.serviceAccount.name` | The name of the service account to use | String: `""` (empty string) |
| `.podAnnotations` | Annotations to add to the pod | Object: `{}` (empty object) |
| `.podLabels` | Labels to add to the pod | Object: `{}` (empty object) |
| `.podSecurityContext` | Security context policies for the pod | Object: `{}` (empty object) |
| `.securityContext` | Security context policies for the container | Object: `{}` (empty object) |
| `.env` | Environment variables for Overseerr | Array: `[]` (empty array) |
| `.service.type` | Service type for Overseerr | String: `"ClusterIP"` |
| `.service.port` | Port number for Overseerr service | Integer: `5055` |
| `.ingress.enabled` | Enable or disable ingress | Boolean: `false` |
| `.ingress.className` | Ingress class name | String: `""` (empty string) |
| `.ingress.annotations` | Annotations for the ingress | Object: `{}` (empty object) |
| `.ingress.hosts` | Hosts configuration for the ingress | Array: `[]` (empty array) |
| `.ingress.tls` | TLS configuration for the ingress | Array: `[]` (empty array) |
| `.cfTunnel.enabled` | Enable or disable Cloudflare Tunnel | Boolean: `false` |
| `.cfTunnel.fqdn` | FQDN for Cloudflare Tunnel | String: `""` (empty string) |
| `.cfTunnel.tunnelName` | Name of the Cloudflare Tunnel | String: `""` (empty string) |
| `.resources` | CPU/Memory resource requests/limits | Object: `{}` (empty object) |
| `.autoscaling.enabled` | Enable or disable autoscaling | Boolean: `false` |
| `.autoscaling.minReplicas` | Minimum number of replicas | Integer: `1` |
| `.autoscaling.maxReplicas` | Maximum number of replicas | Integer: `100` |
| `.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | Integer: `80` |
| `.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | Integer: `80` |
| `.volumes` | Custom volumes for Overseerr | Array: `[]` (empty array) |
| `.volumeMounts` | Mount paths for custom volumes | Array: `[]` (empty array) |
| `.nodeSelector` | Node labels for pod assignment | Object: `{}` (empty object) |
| `.tolerations` | Tolerations for pod assignment | Array: `[]` (empty array) |
| `.affinity` | Affinity settings for pod assignment | Object: `{}` (empty object) |

### Plex

[Plex](https://www.plex.tv/) is a popular media streaming service that organizes movies, TV shows, music, and photos. It streams content across devices, offering a centralized platform for all your media.

#### Values

| Value Name | Description | Structure/Default |
|------------|-------------|-------------------|
| `.enabled` | Enable or disable the Plex service | Boolean: `false` |
| `.replicaCount` | Number of replicas for Plex | Integer: `1` |
| `.image.repository` | Docker image repository for Plex | String: `"linuxserver/plex"` |
| `.image.pullPolicy` | Image pull policy for Plex | String: `"IfNotPresent"` |
| `.image.tag` | Docker image tag for Plex | String: `""` (empty string) |
| `.imagePullSecrets` | Specify image pull secrets | Array: `[]` (empty array) |
| `.nameOverride` | Override the app name | String: `""` (empty string) |
| `.fullnameOverride` | Override the full name of the app | String: `""` (empty string) |
| `.serviceAccount.create` | Specifies whether a service account should be created | Boolean: `true` |
| `.serviceAccount.automount` | Automount service account token | Boolean: `true` |
| `.serviceAccount.annotations` | Annotations to add to the service account | Object: `{}` (empty object) |
| `.serviceAccount.name` | The name of the service account to use | String: `""` (empty string) |
| `.podAnnotations` | Annotations to add to the pod | Object: `{}` (empty object) |
| `.podLabels` | Labels to add to the pod | Object: `{}` (empty object) |
| `.podSecurityContext` | Security context policies for the pod | Object: `{}` (empty object) |
| `.securityContext` | Security context policies for the container | Object: `{}` (empty object) |
| `.env` | Environment variables for Plex | Array: `[]` (empty array) |
| `.service.type` | Service type for Plex | String: `"ClusterIP"` |
| `.service.port` | Port number for Plex service | Integer: `32400` |
| `.ingress.enabled` | Enable or disable ingress | Boolean: `false` |
| `.ingress.className` | Ingress class name | String: `""` (empty string) |
| `.ingress.annotations` | Annotations for the ingress | Object: `{}` (empty object) |
| `.ingress.hosts` | Hosts configuration for the ingress | Array: `[]` (empty array) |
| `.ingress.tls` | TLS configuration for the ingress | Array: `[]` (empty array) |
| `.cfTunnel.enabled` | Enable or disable Cloudflare Tunnel | Boolean: `false` |
| `.cfTunnel.fqdn` | FQDN for Cloudflare Tunnel | String: `""` (empty string) |
| `.cfTunnel.tunnelName` | Name of the Cloudflare Tunnel | String: `""` (empty string) |
| `.runtime.nvidia.enabled` | Enable NVIDIA GPU support | Boolean: `false` |
| `.resources` | CPU/Memory resource requests/limits | Object: `{}` (empty object) |
| `.autoscaling.enabled` | Enable or disable autoscaling | Boolean: `false` |
| `.autoscaling.minReplicas` | Minimum number of replicas | Integer: `1` |
| `.autoscaling.maxReplicas` | Maximum number of replicas | Integer: `100` |
| `.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | Integer: `80` |
| `.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | Integer: `80` |
| `.volumes` | Custom volumes for Plex | Array: `[]` (empty array) |
| `.volumeMounts` | Mount paths for custom volumes | Array: `[]` (empty array) |
| `.nodeSelector` | Node labels for pod assignment | Object: `{}` (empty object) |
| `.tolerations` | Tolerations for pod assignment | Array: `[]` (empty array) |
| `.affinity` | Affinity settings for pod assignment | Object: `{}` (empty object) |

### Prowlarr

[Prowlarr](https://prowlarr.com/) is an indexer manager and proxy that connects with various torrent trackers and Usenet indexers. It is an integral part of the media stack for content discovery.

#### Values

| Value Name | Description | Structure/Default |
|------------|-------------|-------------------|
| `.enabled` | Enable or disable the Prowlarr service | Boolean: `false` |
| `.replicaCount` | Number of replicas for Prowlarr | Integer: `1` |
| `.image.repository` | Docker image repository for Prowlarr | String: `"linuxserver/prowlarr"` |
| `.image.pullPolicy` | Image pull policy for Prowlarr | String: `"IfNotPresent"` |
| `.image.tag` | Docker image tag for Prowlarr | String: `""` (empty string) |
| `.imagePullSecrets` | Specify image pull secrets | Array: `[]` (empty array) |
| `.nameOverride` | Override the app name | String: `""` (empty string) |
| `.fullnameOverride` | Override the full name of the app | String: `""` (empty string) |
| `.serviceAccount.create` | Specifies whether a service account should be created | Boolean: `true` |
| `.serviceAccount.automount` | Automount service account token | Boolean: `true` |
| `.serviceAccount.annotations` | Annotations to add to the service account | Object: `{}` (empty object) |
| `.serviceAccount.name` | The name of the service account to use | String: `""` (empty string) |
| `.podAnnotations` | Annotations to add to the pod | Object: `{}` (empty object) |
| `.podLabels` | Labels to add to the pod | Object: `{}` (empty object) |
| `.podSecurityContext` | Security context policies for the pod | Object: `{}` (empty object) |
| `.securityContext` | Security context policies for the container | Object: `{}` (empty object) |
| `.env` | Environment variables for Prowlarr | Array: `[]` (empty array) |
| `.service.type` | Service type for Prowlarr | String: `"ClusterIP"` |
| `.service.port` | Port number for Prowlarr service | Integer: `9696` |
| `.ingress.enabled` | Enable or disable ingress | Boolean: `false` |
| `.ingress.className` | Ingress class name | String: `""` (empty string) |
| `.ingress.annotations` | Annotations for the ingress | Object: `{}` (empty object) |
| `.ingress.hosts` | Hosts configuration for the ingress | Array: `[]` (empty array) |
| `.ingress.tls` | TLS configuration for the ingress | Array: `[]` (empty array) |
| `.resources` | CPU/Memory resource requests/limits | Object: `{}` (empty object) |
| `.autoscaling.enabled` | Enable or disable autoscaling | Boolean: `false` |
| `.autoscaling.minReplicas` | Minimum number of replicas | Integer: `1` |
| `.autoscaling.maxReplicas` | Maximum number of replicas | Integer: `100` |
| `.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | Integer: `80` |
| `.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | Integer: `80` |
| `.volumes` | Custom volumes for Prowlarr | Array: `[]` (empty array) |
| `.volumeMounts` | Mount paths for custom volumes | Array: `[]` (empty array) |
| `.nodeSelector` | Node labels for pod assignment | Object: `{}` (empty object) |
| `.tolerations` | Tolerations for pod assignment | Array: `[]` (empty array) |
| `.affinity` | Affinity settings for pod assignment | Object: `{}` (empty object) |

### Radarr

[Radarr](https://radarr.video/) is designed for Usenet and BitTorrent users. It manages and downloads movies, integrating with multiple RSS feeds to track and fetch the latest releases.

#### Values

| Value Name | Description | Structure/Default |
|------------|-------------|-------------------|
| `.enabled` | Enable or disable the Radarr service | Boolean: `false` |
| `.replicaCount` | Number of replicas for Radarr | Integer: `1` |
| `.image.repository` | Docker image repository for Radarr | String: `"linuxserver/radarr"` |
| `.image.pullPolicy` | Image pull policy for Radarr | String: `"IfNotPresent"` |
| `.image.tag` | Docker image tag for Radarr | String: `""` (empty string) |
| `.imagePullSecrets` | Specify image pull secrets | Array: `[]` (empty array) |
| `.nameOverride` | Override the app name | String: `""` (empty string) |
| `.fullnameOverride` | Override the full name of the app | String: `""` (empty string) |
| `.serviceAccount.create` | Specifies whether a service account should be created | Boolean: `true` |
| `.serviceAccount.automount` | Automount service account token | Boolean: `true` |
| `.serviceAccount.annotations` | Annotations to add to the service account | Object: `{}` (empty object) |
| `.serviceAccount.name` | The name of the service account to use | String: `""` (empty string) |
| `.podAnnotations` | Annotations to add to the pod | Object: `{}` (empty object) |
| `.podLabels` | Labels to add to the pod | Object: `{}` (empty object) |
| `.podSecurityContext` | Security context policies for the pod | Object: `{}` (empty object) |
| `.securityContext` | Security context policies for the container | Object: `{}` (empty object) |
| `.env` | Environment variables for Radarr | Array: `[]` (empty array) |
| `.service.type` | Service type for Radarr | String: `"ClusterIP"` |
| `.service.port` | Port number for Radarr service | Integer: `7878` |
| `.ingress.enabled` | Enable or disable ingress | Boolean: `false` |
| `.ingress.className` | Ingress class name | String: `""` (empty string) |
| `.ingress.annotations` | Annotations for the ingress | Object: `{}` (empty object) |
| `.ingress.hosts` | Hosts configuration for the ingress | Array: `[]` (empty array) |
| `.ingress.tls` | TLS configuration for the ingress | Array: `[]` (empty array) |
| `.resources` | CPU/Memory resource requests/limits | Object: `{}` (empty object) |
| `.autoscaling.enabled` | Enable or disable autoscaling | Boolean: `false` |
| `.autoscaling.minReplicas` | Minimum number of replicas | Integer: `1` |
| `.autoscaling.maxReplicas` | Maximum number of replicas | Integer: `100` |
| `.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | Integer: `80` |
| `.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | Integer: `80` |
| `.volumes` | Custom volumes for Radarr | Array: `[]` (empty array) |
| `.volumeMounts` | Mount paths for custom volumes | Array: `[]` (empty array) |
| `.nodeSelector` | Node labels for pod assignment | Object: `{}` (empty object) |
| `.tolerations` | Tolerations for pod assignment | Array: `[]` (empty array) |
| `.affinity` | Affinity settings for pod assignment | Object: `{}` (empty object) |

### Sonarr

[Sonarr](https://sonarr.tv/) is similar to Radarr but for TV shows. It's a PVR that monitors RSS feeds for new episodes, automatically downloading them from Usenet and BitTorrent sources.

#### Values

| Value Name | Description | Structure/Default |
|------------|-------------|-------------------|
| `.enabled` | Enable or disable the Sonarr service | Boolean: `false` |
| `.replicaCount` | Number of replicas for Sonarr | Integer: `1` |
| `.image.repository` | Docker image repository for Sonarr | String: `"linuxserver/sonarr"` |
| `.image.pullPolicy` | Image pull policy for Sonarr | String: `"IfNotPresent"` |
| `.image.tag` | Docker image tag for Sonarr | String: `""` (empty string) |
| `.imagePullSecrets` | Specify image pull secrets | Array: `[]` (empty array) |
| `.nameOverride` | Override the app name | String: `""` (empty string) |
| `.fullnameOverride` | Override the full name of the app | String: `""` (empty string) |
| `.serviceAccount.create` | Specifies whether a service account should be created | Boolean: `true` |
| `.serviceAccount.automount` | Automount service account token | Boolean: `true` |
| `.serviceAccount.annotations` | Annotations to add to the service account | Object: `{}` (empty object) |
| `.serviceAccount.name` | The name of the service account to use | String: `""` (empty string) |
| `.podAnnotations` | Annotations to add to the pod | Object: `{}` (empty object) |
| `.podLabels` | Labels to add to the pod | Object: `{}` (empty object) |
| `.podSecurityContext` | Security context policies for the pod | Object: `{}` (empty object) |
| `.securityContext` | Security context policies for the container | Object: `{}` (empty object) |
| `.env` | Environment variables for Sonarr | Array: `[]` (empty array) |
| `.service.type` | Service type for Sonarr | String: `"ClusterIP"` |
| `.service.port` | Port number for Sonarr service | Integer: `8989` |
| `.ingress.enabled` | Enable or disable ingress | Boolean: `false` |
| `.ingress.className` | Ingress class name | String: `""` (empty string) |
| `.ingress.annotations` | Annotations for the ingress | Object: `{}` (empty object) |
| `.ingress.hosts` | Hosts configuration for the ingress | Array: `[]` (empty array) |
| `.ingress.tls` | TLS configuration for the ingress | Array: `[]` (empty array) |
| `.resources` | CPU/Memory resource requests/limits | Object: `{}` (empty object) |
| `.autoscaling.enabled` | Enable or disable autoscaling | Boolean: `false` |
| `.autoscaling.minReplicas` | Minimum number of replicas | Integer: `1` |
| `.autoscaling.maxReplicas` | Maximum number of replicas | Integer: `100` |
| `.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | Integer: `80` |
| `.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | Integer: `80` |
| `.volumes` | Custom volumes for Sonarr | Array: `[]` (empty array) |
| `.volumeMounts` | Mount paths for custom volumes | Array: `[]` (empty array) |
| `.nodeSelector` | Node labels for pod assignment | Object: `{}` (empty object) |
| `.tolerations` | Tolerations for pod assignment | Array: `[]` (empty array) |
| `.affinity` | Affinity settings for pod assignment | Object: `{}` (empty object) |

### Tautulli

[Tautulli](https://tautulli.com/) is a monitoring tool for Plex Media Server. It provides analytics, user tracking, and notifications, giving insights into Plex server usage.

#### Values

| Value Name | Description | Structure/Default |
|------------|-------------|-------------------|
| `.enabled` | Enable or disable the Tautulli service | Boolean: `false` |
| `.replicaCount` | Number of replicas for Tautulli | Integer: `1` |
| `.image.repository` | Docker image repository for Tautulli | String: `"linuxserver/tautulli"` |
| `.image.pullPolicy` | Image pull policy for Tautulli | String: `"IfNotPresent"` |
| `.image.tag` | Docker image tag for Tautulli | String: `""` (empty string) |
| `.imagePullSecrets` | Specify image pull secrets | Array: `[]` (empty array) |
| `.nameOverride` | Override the app name | String: `""` (empty string) |
| `.fullnameOverride` | Override the full name of the app | String: `""` (empty string) |
| `.serviceAccount.create` | Specifies whether a service account should be created | Boolean: `true` |
| `.serviceAccount.automount` | Automount service account token | Boolean: `true` |
| `.serviceAccount.annotations` | Annotations to add to the service account | Object: `{}` (empty object) |
| `.serviceAccount.name` | The name of the service account to use | String: `""` (empty string) |
| `.podAnnotations` | Annotations to add to the pod | Object: `{}` (empty object) |
| `.podLabels` | Labels to add to the pod | Object: `{}` (empty object) |
| `.podSecurityContext` | Security context policies for the pod | Object: `{}` (empty object) |
| `.securityContext` | Security context policies for the container | Object: `{}` (empty object) |
| `.env` | Environment variables for Tautulli | Array: `[]` (empty array) |
| `.service.type` | Service type for Tautulli | String: `"ClusterIP"` |
| `.service.port` | Port number for Tautulli service | Integer: `8181` |
| `.ingress.enabled` | Enable or disable ingress | Boolean: `false` |
| `.ingress.className` | Ingress class name | String: `""` (empty string) |
| `.ingress.annotations` | Annotations for the ingress | Object: `{}` (empty object) |
| `.ingress.hosts` | Hosts configuration for the ingress | Array: `[]` (empty array) |
| `.ingress.tls` | TLS configuration for the ingress | Array: `[]` (empty array) |
| `.resources` | CPU/Memory resource requests/limits | Object: `{}` (empty object) |
| `.autoscaling.enabled` | Enable or disable autoscaling | Boolean: `false` |
| `.autoscaling.minReplicas` | Minimum number of replicas | Integer: `1` |
| `.autoscaling.maxReplicas` | Maximum number of replicas | Integer: `100` |
| `.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | Integer: `80` |
| `.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | Integer: `80` |
| `.volumes` | Custom volumes for Tautulli | Array: `[]` (empty array) |
| `.volumeMounts` | Mount paths for custom volumes | Array: `[]` (empty array) |
| `.nodeSelector` | Node labels for pod assignment | Object: `{}` (empty object) |
| `.tolerations` | Tolerations for pod assignment | Array: `[]` (empty array) |
| `.affinity` | Affinity settings for pod assignment | Object: `{}` (empty object) |

### Tautulli Exporter

The [Tautulli Exporter](https://github.com/nwalke/tautulli-exporter) complements Tautulli by exporting Plex analytics and statistics for Prometheus, enabling advanced data visualization and monitoring.

#### Values

| Value Name | Description | Structure/Default |
|------------|-------------|-------------------|
| `.enabled` | Enable or disable the Tautulli Exporter service | Boolean: `false` |
| `.replicaCount` | Number of replicas for Tautulli Exporter | Integer: `1` |
| `.image.repository` | Docker image repository for Tautulli Exporter | String: `"nwalke/tautulli_exporter"` |
| `.image.pullPolicy` | Image pull policy for Tautulli Exporter | String: `"IfNotPresent"` |
| `.image.tag` | Docker image tag for Tautulli Exporter | String: `""` (empty string) |
| `.imagePullSecrets` | Specify image pull secrets | Array: `[]` (empty array) |
| `.nameOverride` | Override the app name | String: `""` (empty string) |
| `.fullnameOverride` | Override the full name of the app | String: `""` (empty string) |
| `.serviceAccount.create` | Specifies whether a service account should be created | Boolean: `true` |
| `.serviceAccount.automount` | Automount service account token | Boolean: `true` |
| `.serviceAccount.annotations` | Annotations to add to the service account | Object: `{}` (empty object) |
| `.serviceAccount.name` | The name of the service account to use | String: `""` (empty string) |
| `.podAnnotations` | Annotations to add to the pod | Object: `{}` (empty object) |
| `.podLabels` | Labels to add to the pod | Object: `{}` (empty object) |
| `.podSecurityContext` | Security context policies for the pod | Object: `{}` (empty object) |
| `.securityContext` | Security context policies for the container | Object: `{}` (empty object) |
| `.env` | Environment variables for Tautulli Exporter | Array: `[]` (empty array) |
| `.service.type` | Service type for Tautulli Exporter | String: `"ClusterIP"` |
| `.service.port` | Port number for Tautulli Exporter service | Integer: `9487` |
| `.ingress.enabled` | Enable or disable ingress | Boolean: `false` |
| `.ingress.className` | Ingress class name | String: `""` (empty string) |
| `.ingress.annotations` | Annotations for the ingress | Object: `{}` (empty object) |
| `.ingress.hosts` | Hosts configuration for the ingress | Array: `[]` (empty array) |
| `.ingress.tls` | TLS configuration for the ingress | Array: `[]` (empty array) |
| `.serviceMonitor.enabled` | Enable or disable Service Monitor | Boolean: `false` |
| `.resources` | CPU/Memory resource requests/limits | Object: `{}` (empty object) |
| `.autoscaling.enabled` | Enable or disable autoscaling | Boolean: `false` |
| `.autoscaling.minReplicas` | Minimum number of replicas | Integer: `1` |
| `.autoscaling.maxReplicas` | Maximum number of replicas | Integer: `100` |
| `.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | Integer: `80` |
| `.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | Integer: `80` |
| `.volumes` | Custom volumes for Tautulli Exporter | Array: `[]` (empty array) |
| `.volumeMounts` | Mount paths for custom volumes | Array: `[]` (empty array) |
| `.nodeSelector` | Node labels for pod assignment | Object: `{}` (empty object) |
| `.tolerations` | Tolerations for pod assignment | Array: `[]` (empty array) |
| `.affinity` | Affinity settings for pod assignment | Object: `{}` (empty object) |

### Transmission

[Transmission](https://transmissionbt.com/) is a lightweight and cross-platform BitTorrent client. It's known for its simplicity and effectiveness, with capabilities to handle downloads efficiently.

#### Values

| Value Name | Description | Structure/Default |
|------------|-------------|-------------------|
| `.enabled` | Enable or disable the Transmission service | Boolean: `false` |
| `.replicaCount` | Number of replicas for Transmission | Integer: `1` |
| `.image.repository` | Docker image repository for Transmission | String: `"haugene/transmission-openvpn"` |
| `.image.pullPolicy` | Image pull policy for Transmission | String: `"IfNotPresent"` |
| `.image.tag` | Docker image tag for Transmission | String: `""` (empty string) |
| `.imagePullSecrets` | Specify image pull secrets | Array: `[]` (empty array) |
| `.nameOverride` | Override the app name | String: `""` (empty string) |
| `.fullnameOverride` | Override the full name of the app | String: `""` (empty string) |
| `.serviceAccount.create` | Specifies whether a service account should be created | Boolean: `true` |
| `.serviceAccount.automount` | Automount service account token | Boolean: `true` |
| `.serviceAccount.annotations` | Annotations to add to the service account | Object: `{}` (empty object) |
| `.serviceAccount.name` | The name of the service account to use | String: `""` (empty string) |
| `.podAnnotations` | Annotations to add to the pod | Object: `{}` (empty object) |
| `.podLabels` | Labels to add to the pod | Object: `{}` (empty object) |
| `.podSecurityContext` | Security context policies for the pod | Object: `{}` (empty object) |
| `.securityContext.capabilities.add` | Security capabilities to add for Transmission | Array: `["NET_ADMIN"]` |
| `.env` | Environment variables for Transmission | Array: `[]` (empty array) |
| `.service.type` | Service type for Transmission | String: `"ClusterIP"` |
| `.service.port` | Port number for Transmission service | Integer: `9091` |
| `.ingress.enabled` | Enable or disable ingress | Boolean: `false` |
| `.ingress.className` | Ingress class name | String: `""` (empty string) |
| `.ingress.annotations` | Annotations for the ingress | Object: `{}` (empty object) |
| `.ingress.hosts` | Hosts configuration for the ingress | Array: `[]` (empty array) |
| `.ingress.tls` | TLS configuration for the ingress | Array: `[]` (empty array) |
| `.resources` | CPU/Memory resource requests/limits | Object: `{}` (empty object) |
| `.autoscaling.enabled` | Enable or disable autoscaling | Boolean: `false` |
| `.autoscaling.minReplicas` | Minimum number of replicas | Integer: `1` |
| `.autoscaling.maxReplicas` | Maximum number of replicas | Integer: `100` |
| `.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for autoscaling | Integer: `80` |
| `.autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization percentage for autoscaling | Integer: `80` |
| `.volumes` | Custom volumes for Transmission | Array: `[]` (empty array) |
| `.volumeMounts` | Mount paths for custom volumes | Array: `[]` (empty array) |
| `.nodeSelector` | Node labels for pod assignment | Object: `{}` (empty object) |
| `.tolerations` | Tolerations for pod assignment | Array: `[]` (empty array) |
| `.affinity` | Affinity settings for pod assignment | Object: `{}` (empty object) |

## Specialties

- Cloudflare Tunnel: Object template available for `Plex`, `Overseerr`, `Jellyfin` through the template `cloudflare-tunnel.yaml`. This will create a Cloudflare Tunnel for the specified application. You will need to create a Cloudflare Tunnel configuration that can be done using the `Cloudflare Operator`, project details can be found [here](https://github.com/adyanth/cloudflare-operator).
- Nvidia Runtime: Object template available for `Plex`, `Jellyfin` through the template `nvidia-runtime.yaml`. This will create a Nvidia Runtime for the specified application. Tested on k3s cluster using k3s documentation for Nvidia GPU support, documentation can be found [here](https://docs.k3s.io/advanced#nvidia-container-runtime-support).

## License

[MIT License](LICENSE)

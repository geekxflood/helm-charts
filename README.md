# Helm Charts Repository

<p align="center" width="100%">
    <img width="33%" src="assets/icon.png">
</p>

A curated collection of Helm charts for deploying media management, streaming, and automation applications on Kubernetes.

## Table of Contents

- [Helm Charts Repository](#helm-charts-repository)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [Quick Start](#quick-start)
    - [Add Helm Repository](#add-helm-repository)
    - [Install a Chart](#install-a-chart)
    - [Uninstall a Chart](#uninstall-a-chart)
  - [Available Charts](#available-charts)
    - [Media Management](#media-management)
      - [Radarr](#radarr)
      - [Sonarr](#sonarr)
      - [Bazarr](#bazarr)
      - [Prowlarr](#prowlarr)
    - [Media Streaming](#media-streaming)
      - [Plex](#plex)
      - [Jellyfin](#jellyfin)
      - [ErsatzTV](#ersatztv)
      - [DizqueTV](#dizquetv)
    - [Utilities](#utilities)
      - [Overseerr](#overseerr)
      - [Tautulli](#tautulli)
      - [Tautulli Exporter](#tautulli-exporter)
      - [FlareSolverr](#flaresolverr)
      - [Transmission OpenVPN](#transmission-openvpn)
      - [Arr Backup](#arr-backup)
    - [Infrastructure](#infrastructure)
      - [Garage](#garage)
      - [PostgreSQL HA](#postgresql-ha)
      - [OpenBao Unsealer](#openbao-unsealer)
      - [Database Provisioner](#database-provisioner)
      - [OAuth2 Proxy](#oauth2-proxy)
      - [MkDocs Material](#mkdocs-material)
    - [Specialized Applications](#specialized-applications)
      - [Audiobookshelf](#audiobookshelf)
      - [Booksonic Air](#booksonic-air)
      - [Tdarr](#tdarr)
      - [Unmanic](#unmanic)
      - [Whisper](#whisper)
  - [Chart Versions](#chart-versions)
  - [Configuration](#configuration)
    - [Basic Configuration](#basic-configuration)
    - [Storage Configuration](#storage-configuration)
    - [Ingress Configuration](#ingress-configuration)
  - [Advanced Features](#advanced-features)
    - [Cloudflare Tunnel Support](#cloudflare-tunnel-support)
    - [GPU Support](#gpu-support)
  - [Automation](#automation)
    - [GitHub Actions](#github-actions)
      - [Chart Release Workflow](#chart-release-workflow)
      - [Automated Version Management](#automated-version-management)
    - [Update Script](#update-script)
  - [Common Commands](#common-commands)
  - [Version Pinning](#version-pinning)
  - [Notes](#notes)
  - [Contributing](#contributing)
    - [Chart Guidelines](#chart-guidelines)
  - [License](#license)

## Overview

This repository contains production-ready Helm charts for deploying a complete media automation stack on Kubernetes. All charts follow best practices and include:

- ✅ Configurable resource limits and health probes
- ✅ Persistent storage with flexible volume configuration
- ✅ Ingress and service mesh support
- ✅ Optional GPU hardware acceleration
- ✅ Cloudflare Tunnel integration
- ✅ Automated releases via GitHub Actions

**Repository URL**: [https://geekxflood.github.io/helm-charts](https://geekxflood.github.io/helm-charts)

## Prerequisites

- **Kubernetes**: 1.19+ cluster
- **Helm**: 3.0+ client
- **Storage**: Persistent Volume provisioner
- **Optional**:
  - NVIDIA GPU Operator (for hardware transcoding)
  - Cloudflare Tunnel Operator (for secure external access)
  - Ingress Controller (nginx, cilium, traefik, etc.)

## Quick Start

### Add Helm Repository

```bash
helm repo add gxf https://geekxflood.github.io/helm-charts
helm repo update
```

View available charts:

```bash
helm search repo gxf
```

### Install a Chart

Install with default values:

```bash
helm install <release-name> gxf/<chart-name>
```

Install with custom values:

```bash
helm install <release-name> gxf/<chart-name> -f custom-values.yaml
```

Example - Install Plex with GPU support:

```bash
helm install plex gxf/plex \
  --set enabled=true \
  --set gpu.enabled=true \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=plex.example.com
```

### Uninstall a Chart

```bash
helm uninstall <release-name>
```

## Available Charts

### Media Management

| Chart                     | Version | App Version | Description                |
| ------------------------- | ------- | ----------- | -------------------------- |
| **[radarr](#radarr)**     | 0.4.0   | 5.23.1      | Movie collection manager   |
| **[sonarr](#sonarr)**     | 0.4.0   | 4.0.16      | TV show collection manager |
| **[bazarr](#bazarr)**     | 0.5.0   | 1.5.2       | Subtitle management        |
| **[prowlarr](#prowlarr)** | 1.0.0   | 2.0.5       | Indexer manager and proxy  |

#### Radarr

Movie collection manager for Usenet and BitTorrent users. Monitors RSS feeds for new releases and automatically downloads, organizes, and manages your movie library with quality profiles and metadata fetching.

```bash
helm install radarr gxf/radarr
```

#### Sonarr

TV show collection manager that monitors RSS feeds for new episodes. Automatically downloads, sorts, and renames files. Supports quality profiles, season tracking, and calendar integration.

```bash
helm install sonarr gxf/sonarr
```

#### Bazarr

Companion application for Sonarr and Radarr that automatically downloads subtitles in multiple languages. Features subtitle providers integration, automatic sync, and embedded subtitle support.

```bash
helm install bazarr gxf/bazarr
```

#### Prowlarr

Indexer manager and proxy that works with Sonarr, Radarr, and other *arr applications. Provides centralized management of trackers and Usenet indexers with sync capabilities.

```bash
helm install prowlarr gxf/prowlarr
```

### Media Streaming

| Chart                     | Version | App Version  | GPU  | Description              |
| ------------------------- | ------- | ------------ | ---- | ------------------------ |
| **[plex](#plex)**         | 0.4.0   | 1.42.2       | ✅   | Popular media server     |
| **[jellyfin](#jellyfin)** | 0.2.0   | 10.11.3      | ⚙️ | Open-source media server |
| **[ersatztv](#ersatztv)** | 1.0.0   | v25.2.0      | ⚙️ | Custom live TV channels  |
| **[dizquetv](#dizquetv)** | 0.1.0   | 1.5.5        | ❌   | Plex custom channels     |

#### Plex

Popular media server for streaming movies, TV shows, music, and photos to any device. Supports hardware transcoding with NVIDIA GPU, mobile apps, remote access, and Plex Pass features.

```bash
helm install plex gxf/plex
```

**GPU Support**: ✅ NVIDIA hardware transcoding enabled by default

#### Jellyfin

Open-source alternative to Plex. Stream your media library without subscriptions or restrictions. Features plugin system, hardware acceleration, and multiple client support.

```bash
helm install jellyfin gxf/jellyfin
```

**GPU Support**: ⚙️ Configurable NVIDIA/VAAPI

#### ErsatzTV

Create custom live TV channels from your Plex, Jellyfin, or Emby library. Features channel scheduling, commercial breaks, and EPG generation for a classic broadcast TV experience.

```bash
helm install ersatztv gxf/ersatztv
```

**GPU Support**: ⚙️ VAAPI hardware acceleration

#### DizqueTV

Create custom TV channels from your Plex library with FFMPEG integration. Features channel editor, commercial injection, and M3U/XMLTV output.

```bash
helm install dizquetv gxf/dizquetv
```

### Utilities

| Chart                                             | Version | App Version | Description                    |
| ------------------------------------------------- | ------- | ----------- | ------------------------------ |
| **[overseerr](#overseerr)**                       | 0.2.0   | 1.34.0      | Request management for Plex    |
| **[tautulli](#tautulli)**                         | 0.2.0   | 2.16.0      | Plex monitoring and analytics  |
| **[tautulli-exporter](#tautulli-exporter)**       | 0.1.0   | v0.1.0      | Prometheus exporter            |
| **[flaresolverr](#flaresolverr)**                 | 0.2.0   | v3.4.5      | Cloudflare bypass proxy        |
| **[transmission-openvpn](#transmission-openvpn)** | 0.1.0   | 5.3.1       | BitTorrent with VPN            |
| **[arr-backup](#arr-backup)**                     | 1.0.0   | N/A         | Automated backup for *arr apps |

#### Overseerr

Request management and media discovery tool for Plex. User-friendly interface for requesting movies and TV shows with approval workflows, Plex integration, and notifications.

```bash
helm install overseerr gxf/overseerr
```

#### Tautulli

Monitoring and analytics for Plex Media Server. Track watch history, user statistics, send notifications, and generate newsletters.

```bash
helm install tautulli gxf/tautulli
```

#### Tautulli Exporter

Prometheus exporter for Tautulli metrics. Monitor Plex statistics in Grafana with custom metrics and dashboards.

```bash
helm install tautulli-exporter gxf/tautulli-exporter
```

#### FlareSolverr

Proxy server to bypass Cloudflare anti-bot protection. Essential for web scrapers and RSS readers that need to access protected content.

```bash
helm install flaresolverr gxf/flaresolverr
```

#### Transmission OpenVPN

BitTorrent client with built-in OpenVPN support for secure downloading. Features VPN kill switch, multiple provider support, and automatic port forwarding.

```bash
helm install transmission gxf/transmission-openvpn
```

⚠️ **Requires**: OpenVPN credentials configuration

#### Arr Backup

Automated backup solution for Radarr, Sonarr, Prowlarr, and Bazarr. Scheduled CronJob that creates compressed archives of application configurations and stores them in persistent storage.

```bash
helm install arr-backup gxf/arr-backup
```

**Features**: Automated scheduling, compressed backups, retention policies

### Infrastructure

| Chart                                             | Version | App Version | Description                        |
| ------------------------------------------------- | ------- | ----------- | ---------------------------------- |
| **[garage](#garage)**                             | 1.0.0   | v2.1.0      | S3-compatible object storage       |
| **[postgres-ha](#postgres-ha)**                   | 1.0.0   | 16.10       | HA PostgreSQL with CloudNativePG   |
| **[openbao-unsealer](#openbao-unsealer)**         | 1.0.0   | 2.3.1       | Automated OpenBao unsealing        |
| **[database-provisioner](#database-provisioner)** | 1.0.0   | N/A         | CloudNativePG database provisioner |
| **[oauth2-proxy](#oauth2-proxy)**                 | 1.0.0   | 7.13.0      | OAuth2/OIDC authentication proxy   |
| **[mkdocs-material](#mkdocs-material)**           | 1.0.0   | 9.7.0       | Material Design documentation      |

#### Garage

Lightweight S3-compatible object storage designed for self-hosting. Distributed architecture with geo-replication support, perfect for small to medium deployments.

```bash
helm install garage gxf/garage
```

**Features**: S3 API compatibility, distributed storage, web hosting, replication modes

⚠️ **Configuration Required**: Generate RPC secret with `openssl rand -hex 32` before deployment

#### PostgreSQL HA

High-availability PostgreSQL cluster using CloudNativePG operator. Features automatic failover, point-in-time recovery, and connection pooling with PgBouncer.

```bash
helm install postgres-ha gxf/postgres-ha
```

**Features**: CloudNativePG operator, PgBouncer pooling, automated backups, monitoring

**Prerequisites**: CloudNativePG operator installed in cluster

#### OpenBao Unsealer

Automated unsealing service for OpenBao (HashiCorp Vault fork) clusters. Monitors sealed status and automatically unseals using Kubernetes-stored keys.

```bash
helm install openbao-unsealer gxf/openbao-unsealer
```

**Features**: Automatic unsealing, CronJob scheduling, secure key management

**Prerequisites**: OpenBao cluster deployed, unseal keys stored in Kubernetes secrets

#### Database Provisioner

Automated provisioner for CloudNativePG Database custom resources. Creates and manages databases with user credentials via CronJob scheduling.

```bash
helm install database-provisioner gxf/database-provisioner
```

**Features**: Automated database creation, user provisioning, CronJob-based

**Prerequisites**: CloudNativePG operator and cluster deployed

#### OAuth2 Proxy

Authentication proxy for adding OAuth2/OIDC authentication to applications. Works with Keycloak, Google, GitHub, and other identity providers.

```bash
helm install oauth2-proxy gxf/oauth2-proxy
```

**Features**: OIDC/OAuth2 support, Keycloak integration, cookie-based sessions

**Use Case**: Protect applications without built-in authentication

#### MkDocs Material

Material Design themed documentation site generator. Deploy static documentation with search, navigation, and modern UI.

```bash
helm install mkdocs-material gxf/mkdocs-material
```

**Features**: Material Design theme, full-text search, responsive design

**Use Case**: Technical documentation, API docs, project wikis

### Specialized Applications

| Chart                                 | Version | App Version | GPU  | Description                |
| ------------------------------------- | ------- | ----------- | ---- | -------------------------- |
| **[audiobookshelf](#audiobookshelf)** | 0.4.0   | 2.30.0      | ❌   | Audiobook & podcast server |
| **[tdarr](#tdarr)**                   | 1.3.0   | 2.33.01     | ⚙️ | Distributed transcoding    |
| **[unmanic](#unmanic)**               | 0.2.0   | 0.3.0       | ❌   | Library optimizer          |
| **[whisper](#whisper)**               | 1.2.0   | 1.6.1-gpu   | ✅   | Speech recognition AI      |

#### Audiobookshelf

Self-hosted audiobook and podcast server with progress tracking, bookmarks, and mobile app support. Manage and stream your audiobook library with multi-user support.

```bash
helm install audiobookshelf gxf/audiobookshelf
```

#### Tdarr

Distributed transcode system for automating media library transcoding and remuxing. Features distributed worker nodes, plugin system, health checking, and codec conversion.

```bash
helm install tdarr gxf/tdarr
```

**GPU Support**: ⚙️ NVIDIA hardware acceleration configurable

**Related Charts**:

- `tdarr-server` (v0.2.0) - Server component
- `tdarr-node` (v0.2.0) - Worker nodes for distributed processing

#### Unmanic

Library optimizer for automatic video, audio, and image file conversion. Features plugin system, scheduled tasks, file monitoring, and batch processing.

```bash
helm install unmanic gxf/unmanic
```

#### Whisper

OpenAI Whisper ASR webservice for automatic speech recognition and subtitle generation. Supports multiple languages, Bazarr integration, and API interface.

```bash
helm install whisper gxf/whisper
```

**GPU Support**: ✅ NVIDIA GPU required for optimal performance

## Chart Versions

| Chart                | Chart Version | App Version  | Image Repository                        |
| -------------------- | ------------- | ------------ | --------------------------------------- |
| arr-backup           | 1.0.0         | N/A          | busybox                                 |
| audiobookshelf       | 0.4.0         | 2.30.0       | ghcr.io/advplyr/audiobookshelf          |
| bazarr               | 0.5.0         | 1.5.2        | linuxserver/bazarr                      |
| database-provisioner | 1.0.0         | N/A          | postgres:17-alpine                      |
| dizquetv             | 0.1.0         | 1.5.5        | vexorian/dizquetv                       |
| ersatztv             | 1.0.0         | v25.2.0      | ghcr.io/ersatztv/ersatztv               |
| flaresolverr         | 0.2.0         | v3.4.5       | ghcr.io/flaresolverr/flaresolverr       |
| garage               | 1.0.0         | v2.1.0       | dxflrs/garage                           |
| jellyfin             | 0.2.0         | 10.11.3      | linuxserver/jellyfin                    |
| mkdocs-material      | 1.0.0         | 9.7.0        | squidfunk/mkdocs-material               |
| oauth2-proxy         | 1.0.0         | 7.13.0       | quay.io/oauth2-proxy/oauth2-proxy       |
| openbao-unsealer     | 1.0.0         | 2.3.1        | quay.io/openbao/openbao                 |
| overseerr            | 0.2.0         | 1.34.0       | linuxserver/overseerr                   |
| plex                 | 0.4.0         | 1.42.2       | linuxserver/plex                        |
| postgres-ha          | 1.0.0         | 16.10        | ghcr.io/cloudnative-pg/postgresql       |
| prowlarr             | 1.0.0         | 2.0.5        | linuxserver/prowlarr                    |
| radarr               | 0.4.0         | 5.23.1       | linuxserver/radarr                      |
| sonarr               | 0.4.0         | 4.0.16       | linuxserver/sonarr                      |
| tautulli             | 0.2.0         | 2.16.0       | linuxserver/tautulli                    |
| tautulli-exporter    | 0.1.0         | v0.1.0       | nwalke/tautulli_exporter                |
| tdarr                | 1.3.0         | 2.33.01      | ghcr.io/haveagitgat/tdarr               |
| tdarr-node           | 0.2.0         | 2.33.01      | ghcr.io/haveagitgat/tdarr_node          |
| tdarr-server         | 0.2.0         | 2.33.01      | ghcr.io/haveagitgat/tdarr               |
| transmission-openvpn | 0.1.0         | 5.3.1        | haugene/transmission-openvpn            |
| unmanic              | 0.2.0         | 0.3.0        | josh5/unmanic                           |
| whisper              | 1.2.0         | 1.6.1-gpu    | onerahmet/openai-whisper-asr-webservice |

## Configuration

### Basic Configuration

All charts support standard Kubernetes configuration options:

```yaml
# Enable the application
enabled: true

# Number of replicas
replicaCount: 1

# Image configuration
image:
  repository: <image-repository>
  pullPolicy: IfNotPresent
  tag: "<version>"

# Environment variables (LinuxServer.io images)
env:
  - name: PUID
    value: "1000"  # User ID for file permissions
  - name: PGID
    value: "100"   # Group ID for file permissions
  - name: TZ
    value: "UTC"   # Timezone
```

### Storage Configuration

Persistent storage for configuration and media:

```yaml
volumes:
  - name: config
    persistentVolumeClaim:
      claimName: app-config-pvc
  - name: media
    persistentVolumeClaim:
      claimName: app-media-pvc

volumeMounts:
  - name: config
    mountPath: /config
  - name: media
    mountPath: /data
```

### Ingress Configuration

Expose applications via ingress controller:

```yaml
ingress:
  enabled: true
  className: nginx  # or cilium, traefik, etc.
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: app-tls
      hosts:
        - app.example.com
```

## Advanced Features

### Cloudflare Tunnel Support

Secure external access without exposing ports publicly:

```yaml
cfTunnel:
  enabled: true
  fqdn: "app.example.com"
  tunnelName: "my-k8s-tunnel"
```

**Supported Charts**: plex, jellyfin, overseerr, booksonic-air

**Prerequisites**: Install [Cloudflare Operator](https://github.com/adyanth/cloudflare-operator)

### GPU Support

Hardware acceleration for transcoding and AI workloads:

```yaml
# For Plex-style GPU config
gpu:
  enabled: true
  runtimeClass: nvidia
  count: 1

nodeSelector:
  nvidia.com/gpu.present: "true"
```

Or for simple runtime class:

```yaml
runtime:
  enabled: true
  name: nvidia
```

**GPU-Enabled Charts**:

- ✅ **plex**: Full GPU transcoding support
- ⚙️ **jellyfin**: Configurable GPU support
- ⚙️ **ersatztv**: VAAPI support
- ⚙️ **tdarr**: Distributed GPU transcoding
- ✅ **whisper**: GPU-accelerated AI inference

**Requirements**:

- NVIDIA GPU Operator or device plugin installed
- RuntimeClass configured: `kubectl get runtimeclass`
- GPU nodes labeled appropriately

## Automation

### GitHub Actions

This repository uses automated workflows for:

#### Chart Release Workflow

Automatically packages and publishes charts on every push to `main`:

- **Helm chart packaging** via chart-releaser-action
- **GitHub Releases** with auto-generated release notes
- **OCI registry push** to GitHub Container Registry (ghcr.io)
- **GitHub Pages** index update at <https://geekxflood.github.io/helm-charts>

The workflow runs on every commit to main that changes chart files.

#### Automated Version Management

To update chart versions:

1. Update `version` in `Chart.yaml` (chart version)
2. Update `appVersion` in `Chart.yaml` (app version)
3. Update `image.tag` in `values.yaml` (container image tag)
4. Push to main branch
5. GitHub Actions automatically:
   - Lints the chart
   - Packages the new version
   - Creates a GitHub release
   - Pushes to OCI registry
   - Updates Helm repository index

### Update Script

For bulk updates, use the provided script:

```bash
./update_charts.sh
```

This script:

- Updates all chart versions
- Updates application versions
- Updates container image tags
- Maintains consistent formatting

## Common Commands

```bash
# List all charts
helm search repo gxf

# Show chart details
helm show chart gxf/<chart-name>

# Show default values
helm show values gxf/<chart-name>

# Install with custom values
helm install <release> gxf/<chart> -f values.yaml

# Upgrade existing release
helm upgrade <release> gxf/<chart> -f values.yaml

# Rollback to previous version
helm rollback <release>

# View release history
helm history <release>

# Uninstall release
helm uninstall <release>

# Lint a chart locally
helm lint charts/<chart-name>

# Package a chart locally
helm package charts/<chart-name>
```

## Version Pinning

For production deployments, always pin specific chart versions:

```bash
# Install specific chart version
helm install <release> gxf/<chart> --version 0.3.0

# Show available versions
helm search repo gxf/<chart> --versions
```

## Notes

- **Last Updated**: 2024-11-24
- All charts updated with latest stable application versions
- Image tags explicitly pinned for production stability
- GPU-enabled charts require NVIDIA GPU Operator
- Most charts use [LinuxServer.io](https://www.linuxserver.io/) images for consistent PUID/PGID support
- Automated releases via GitHub Actions on every push to main

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test locally (`helm lint`, `helm install --dry-run`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Chart Guidelines

- Follow [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- Pin image tags (avoid `latest`)
- Include health probes (liveness/readiness)
- Document all values in `values.yaml`
- Test with `helm lint` and `helm install --dry-run`
- Increment chart version on every change

## License

[MIT License](LICENSE)

---

<p align="center">
  <strong>Maintained by</strong>: <a href="https://github.com/geekxflood">geekxflood</a><br>
  <strong>Repository</strong>: <a href="https://github.com/geekxflood/helm-charts">github.com/geekxflood/helm-charts</a><br>
  <strong>Chart Index</strong>: <a href="https://geekxflood.github.io/helm-charts">geekxflood.github.io/helm-charts</a>
</p>

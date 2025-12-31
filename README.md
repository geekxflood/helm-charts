# Helm Charts

A collection of Helm charts for various applications, focused on media management, home automation, and utilities.

## Usage

To use these charts, clone this repository or add it as a local Helm repository.

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

## Available Charts

| Chart | Version | App Version | Description |
|---|---|---|---|
| arr-backup | 1.0.1 | 1.0.0 | Automated backup solution for Radarr, Sonarr, Prowlarr, and Bazarr using their native backup APIs |
| audiobookshelf | 0.5.0 | latest | Audiobookshelf - Self-hosted audiobook and podcast server |
| bazarr | 0.5.1 | 1.5.2 | Bazarr - Subtitle management for Sonarr and Radarr |
| database-provisioner | 1.0.0 | 1.0 | Automated database provisioner for CloudNativePG Database CRDs |
| dizquetv | 0.1.0 | 1.5.5 | A Helm chart for Kubernetes for deploying DizqueTV |
| ersatztv | 1.1.0 | v25.2.0 | A Helm chart for ErsatzTV - custom live TV channels using your media library |
| flaresolverr | 0.2.1 | v3.4.6 | A Helm chart for Kubernetes for deploying Flaresolverr |
| garage | 1.0.1 | v2.1.0 | S3-compatible object store for small self-hosted geo-distributed deployments |
| jellyfin | 0.9.1 | 10.11.5 | A Helm chart for Kubernetes for deploying Jellyfin Media Server |
| keycloak | 0.11.4 | 26.0.7 | A Helm chart for Keycloak - Open Source Identity and Access Management |
| lazylibrarian | 0.1.0 | latest | LazyLibrarian - Automated ebook and audiobook manager |
| mkdocs-material | 1.0.1 | 9.7.0 | MkDocs Material theme documentation site with git-sync for auto-updates |
| oauth2-proxy | 1.0.1 | 7.13.1 | OAuth2 Proxy for authenticating applications via Keycloak OIDC |
| ollama | 1.0.0 | 0.4.6 | Ollama - Run large language models locally with GPU support |
| open-webui | 1.0.0 | 0.4.8 | Open WebUI - User-friendly web interface for LLMs like Ollama |
| openbao-unsealer | 1.0.0 | 2.3.1 | Automated unsealing for OpenBao cluster using unseal keys from Kubernetes secret |
| overseer | 0.3.1 | 1.33.2 | A Helm chart for Kubernetes |
| overseerr | 0.2.1 | 1.34.0 | A Helm chart for Kubernetes for deploying Overseerr |
| plex | 0.4.0 | 1.42.2 | A Helm chart for deploying Plex Media Server on Kubernetes |
| postgres-ha | 1.0.0 | 16 | High-availability PostgreSQL cluster using CloudNativePG |
| program-director | 1.1.4 | 1.1.1 | AI-powered TV channel programmer for Tunarr |
| prowlarr | 1.0.1 | 2.0.5 | A Helm chart for Kubernetes |
| radarr | 0.4.1 | 5.23.1 | A Helm chart for deploying Radarr on Kubernetes |
| readarr | 0.1.0 | 0.4.4.2686 | A Helm chart for deploying Readarr on Kubernetes |
| rreading-glasses | 0.1.1 | latest | Metadata service for book and audiobook management applications |
| seerr | 1.0.0 | develop | Open-source media request and discovery manager for Jellyfin, Plex, and Emby |
| sonarr | 0.4.1 | 4.0.16 | A Helm chart for deploying Sonarr on Kubernetes |
| subgen | 1.0.0 | 2024.12.1 | SubGen - Autogenerate subtitles using OpenAI Whisper Model |
| tautulli-exporter | 0.1.0 | v0.1.0 | A Helm chart for Kubernetes for deploying Tautulli-exporter |
| tautulli | 0.2.0 | 2.16.0 | A Helm chart for Kubernetes for deploying Tautulli |
| tdarr_node | 0.5.0 | 2.33.01 | A Helm chart for Kubernetes for deploying tdarr transcoding nodes |
| tdarr_server | 0.4.0 | 2.33.01 | A Helm chart for Kubernetes for deploying tdarr server |
| tdarr | 1.3.0 | 2.33.01 | Tdarr Helm chart for Kubernetes - Distributed transcode system for automating media library transcode/remux management |
| transmission-openvpn | 0.1.0 | 5.3.1 | A Helm chart for Kubernetes for deploying Transmission |
| tunarr | 0.2.0 | 0.22.17 | A Helm chart for Tunarr - Create live TV channels from media on your Plex/Jellyfin/Emby servers with built-in HDHomeRun emulation |
| unmanic | 0.2.0 | 0.3.0 | A Helm chart for Kubernetes for deploying Unmanic |
| whisper | 1.2.0 | 1.6.1-gpu | OpenAI Whisper ASR Webservice for automatic speech recognition and subtitle generation with Bazarr |
| wizarr | 0.1.1 | 2025.12.0 | A Helm chart for deploying Wizarr - automatic user invitation and management system for media servers |

## License

This repository is licensed under the Apache License 2.0.

Individual charts may have different licenses - please refer to each chart's README for details.

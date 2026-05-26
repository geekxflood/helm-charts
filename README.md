# Helm Charts

A collection of Helm charts for self-hosted media (Plex / Jellyfin / *arr stack), Kubernetes infrastructure (Keycloak, oauth2-proxy, CloudNativePG, OpenBao, Garage), AI/LLM runtimes (Ollama, Open WebUI, Whisper), and supporting utilities.

> **Documentation site:** <https://geekxflood.github.io/helm-charts/>
>
> Bespoke per-chart pages with auto-generated values references, install snippets, and category browsing. Built statically from this repository.

## Add the repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm search repo geekxflood
```

The same URL hosts both the Helm repository (`index.yaml`) **and** the documentation site. The two coexist at the root of the `gh-pages` branch — adding the repo with `helm repo add` keeps working regardless of what the website looks like.

OCI install (alternative, hosted on GHCR):

```bash
helm install <release> oci://ghcr.io/geekxflood/charts/<chart-name> --version <version>
```

## Ingress and Gateway API support

Charts in this repository expose HTTP traffic via **either** a Kubernetes `Ingress` **or** a Gateway API `HTTPRoute`. Both objects coexist and can be toggled independently per release — there is no global flag. The HTTPRoute templates are vanilla Gateway API (`gateway.networking.k8s.io/v1`) and work with any conformant controller (Cilium Gateway API, Istio, Envoy Gateway, etc.).

Migration from Ingress to Gateway API is opt-in per deployment: set `ingress.enabled=false` and `httpRoute.enabled=true` (plus a `parentRefs` entry pointing at your Gateway listener). Backends default to the chart's own service, so a minimal route only needs `parentRefs`, `hostnames`, and one rule `match`.

```bash
helm upgrade --install audiobookshelf charts/audiobookshelf \
  --set ingress.enabled=false \
  --set httpRoute.enabled=true \
  --set 'httpRoute.parentRefs[0].name=cilium-gateway' \
  --set 'httpRoute.parentRefs[0].namespace=gateway-system' \
  --set 'httpRoute.hostnames[0]=audiobookshelf.example.com' \
  --set 'httpRoute.rules[0].matches[0].path.value=/'
```

Cilium notes: `parentRefs[*].port` is ignored — target a listener with `sectionName`. Cross-namespace `backendRefs` require a `ReferenceGrant` in the backend namespace.

## Available Charts

Browse with full per-chart documentation on the site: <https://geekxflood.github.io/helm-charts/>

<!-- charts:start -->

| Chart | Version | App Version | Description |
|---|---|---|---|
| [audiobookshelf](charts/audiobookshelf) | 0.6.0 | latest | Audiobookshelf - Self-hosted audiobook and podcast server |
| [backuparr](charts/backuparr) | 1.2.1 | 1.2.0 | Automated backup solution for *arr applications using their native APIs |
| [bazarr](charts/bazarr) | 0.6.0 | 1.5.2 | Bazarr - Subtitle management for Sonarr and Radarr |
| [bench](charts/bench) | 0.1.0 | latest | A Helm chart for deploying bench — a static WoW raid bench roller |
| [cleanuparr](charts/cleanuparr) | 0.2.0 | 1.0.0 | A Helm chart for deploying Cleanuparr - Media library cleanup tool |
| [database-provisioner](charts/database-provisioner) | 1.0.0 | 1.0 | Automated database provisioner for CloudNativePG Database CRDs |
| [dizquetv](charts/dizquetv) | 0.2.1 | 1.7.0 | A Helm chart for Kubernetes for deploying DizqueTV |
| [ersatztv](charts/ersatztv) | 1.2.0 | v25.2.0 | A Helm chart for ErsatzTV - custom live TV channels using your media library |
| [flaresolverr](charts/flaresolverr) | 0.3.0 | v3.4.6 | A Helm chart for Kubernetes for deploying Flaresolverr |
| [garage](charts/garage) | 1.1.1 | v2.3.0 | S3-compatible object store for small self-hosted geo-distributed deployments |
| [huntarr](charts/huntarr) | 0.2.0 | 1.0.0 | A Helm chart for deploying Huntarr - Automated missing media finder for *arr apps |
| [jellyfin](charts/jellyfin) | 0.11.1 | 10.11.8 | A Helm chart for Kubernetes for deploying Jellyfin Media Server |
| [kapowarr](charts/kapowarr) | 0.2.0 | 1.0.0 | A Helm chart for deploying Kapowarr - Comic book library manager |
| [keycloak](charts/keycloak) | 0.12.1 | 26.6.1 | A Helm chart for Keycloak - Open Source Identity and Access Management |
| [lazylibrarian](charts/lazylibrarian) | 0.2.0 | latest | LazyLibrarian - Automated ebook and audiobook manager |
| [lingarr](charts/lingarr) | 0.2.0 | 1.0.0 | A Helm chart for deploying Lingarr - Automatic subtitle translator |
| [mkdocs-material](charts/mkdocs-material) | 1.1.1 | 9.7.6 | MkDocs Material theme documentation site with git-sync for auto-updates |
| [oauth2-proxy](charts/oauth2-proxy) | 1.0.2 | 7.15.2 | OAuth2 Proxy for authenticating applications via Keycloak OIDC |
| [ollama](charts/ollama) | 1.0.0 | 0.4.6 | Ollama - Run large language models locally with GPU support |
| [open-webui](charts/open-webui) | 1.1.0 | 0.4.8 | Open WebUI - User-friendly web interface for LLMs like Ollama |
| [openbao-unsealer](charts/openbao-unsealer) | 1.0.0 | 2.3.1 | Automated unsealing for OpenBao cluster using unseal keys from Kubernetes secret |
| [openwatchparty](charts/openwatchparty) | 0.2.0 | latest | OpenWatchParty - Synchronized media playback for Jellyfin watch parties |
| [overseer](charts/overseer) | 0.4.0 | 1.33.2 | A Helm chart for Kubernetes |
| [overseerr](charts/overseerr) | 0.3.1 | 1.35.0 | A Helm chart for Kubernetes for deploying Overseerr |
| [plex](charts/plex) | 0.5.0 | 1.42.2 | A Helm chart for deploying Plex Media Server on Kubernetes |
| [posterizarr](charts/posterizarr) | 0.2.0 | latest | Automated poster generation for media libraries with Web UI support for Plex, Jellyfin, and Emby |
| [postgres-ha](charts/postgres-ha) | 1.0.0 | 16 | High-availability PostgreSQL cluster using CloudNativePG |
| [program-director](charts/program-director) | 1.2.0 | 1.1.1 | AI-powered TV channel programmer for Tunarr |
| [prowlarr](charts/prowlarr) | 1.1.0 | 2.0.5 | A Helm chart for Kubernetes |
| [radarr](charts/radarr) | 0.5.0 | 5.23.1 | A Helm chart for deploying Radarr on Kubernetes |
| [readarr](charts/readarr) | 0.2.0 | 0.4.4.2686 | A Helm chart for deploying Readarr on Kubernetes |
| [rreading-glasses](charts/rreading-glasses) | 0.2.0 | latest | Metadata service for book and audiobook management applications |
| [sabnzbd](charts/sabnzbd) | 0.2.0 | latest | A Helm chart for SABnzbd - Usenet Downloader |
| [seerr](charts/seerr) | 1.1.0 | develop | Open-source media request and discovery manager for Jellyfin, Plex, and Emby |
| [sonarr](charts/sonarr) | 0.5.0 | 4.0.16 | A Helm chart for deploying Sonarr on Kubernetes |
| [subgen](charts/subgen) | 1.0.0 | 2024.12.1 | SubGen - Autogenerate subtitles using OpenAI Whisper Model |
| [tautulli-exporter](charts/tautulli-exporter) | 0.2.0 | v0.1.0 | A Helm chart for Kubernetes for deploying Tautulli-exporter |
| [tautulli](charts/tautulli) | 0.3.1 | 2.17.1 | A Helm chart for Kubernetes for deploying Tautulli |
| [tdarr](charts/tdarr) | 1.4.1 | 2.73.01 | Tdarr Helm chart for Kubernetes - Distributed transcode system for automating media library transcode/remux management |
| [tdarr-node](charts/tdarr_node) | 0.6.1 | 2.73.01 | A Helm chart for Kubernetes for deploying tdarr transcoding nodes |
| [tdarr-server](charts/tdarr_server) | 0.5.1 | 2.73.01 | A Helm chart for Kubernetes for deploying tdarr server |
| [transmission-openvpn](charts/transmission-openvpn) | 0.2.1 | 5.4.1 | A Helm chart for Kubernetes for deploying Transmission |
| [tunarr](charts/tunarr) | 0.5.0 | 1.2.17 | A Helm chart for Tunarr - Create live TV channels from media on your Plex/Jellyfin/Emby servers with built-in HDHomeRun emulation |
| [unmanic](charts/unmanic) | 0.3.1 | 0.4.0 | A Helm chart for Kubernetes for deploying Unmanic |
| [whisper](charts/whisper) | 1.3.0 | 1.6.1-gpu | OpenAI Whisper ASR Webservice for automatic speech recognition and subtitle generation with Bazarr |
| [wizarr](charts/wizarr) | 0.2.1 | 2026.4.0 | A Helm chart for deploying Wizarr - automatic user invitation and management system for media servers |

<!-- charts:end -->

## License

This repository is licensed under the Apache License 2.0.

Individual charts may have different licenses - please refer to each chart's README for details.

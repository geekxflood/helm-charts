# OpenWatchParty Helm Chart

A Helm chart for deploying the OpenWatchParty session server - synchronized media playback for Jellyfin watch parties.

## Overview

OpenWatchParty enables synchronized media playback across multiple browsers for Jellyfin. Users can create or join watch parties with a single click and enjoy movies together with real-time synchronization of play, pause, and seek actions.

**Source**: [github.com/mhbxyz/OpenWatchParty](https://github.com/mhbxyz/OpenWatchParty)

## Architecture

The OpenWatchParty system consists of three components:

1. **Jellyfin Plugin** (C#): Serves client scripts and generates JWT tokens
2. **Session Server** (Rust): Manages rooms and relays synchronization via WebSocket - **this chart**
3. **Web Client** (JavaScript): Provides UI integration and playback control

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Jellyfin 10.9+ with the OpenWatchParty plugin installed

### Jellyfin Plugin Setup

1. Add the plugin repository to Jellyfin:
   ```
   https://mhbxyz.github.io/OpenWatchParty/jellyfin-plugin-repo/manifest.json
   ```

2. Install the plugin via Jellyfin Dashboard → Plugins → Catalog

3. Enable the client script in Dashboard → General → Custom HTML:
   ```html
   <script src="/web/plugins/openwatchparty/plugin.js"></script>
   ```

4. Configure the plugin to point to this session server

## Installation

```bash
helm install openwatchparty ./charts/openwatchparty \
  --namespace media \
  --set env.ALLOWED_ORIGINS="https://jellyfin.example.com"
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Image repository | `ghcr.io/mhbxyz/openwatchparty-session-server` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `env.ALLOWED_ORIGINS` | Allowed origins for CORS (your Jellyfin URL) | `http://localhost:8096` |
| `extraEnv` | Additional environment variables | `[]` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `3000` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.hosts` | Ingress hosts configuration | `[]` |
| `ingress.tls` | Ingress TLS configuration | `[]` |
| `resources` | Resource requests/limits | `{}` |
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `10` |

## Example Values

### Basic Installation

```yaml
env:
  ALLOWED_ORIGINS: "https://jellyfin.example.com"

service:
  type: ClusterIP
  port: 3000
```

### With Ingress (Cilium)

```yaml
env:
  ALLOWED_ORIGINS: "https://jellyfin.example.com"

ingress:
  enabled: true
  className: cilium
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: watchparty.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: watchparty-tls
      hosts:
        - watchparty.example.com
```

### With Resource Limits

```yaml
resources:
  limits:
    cpu: 500m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 64Mi
```

## Usage

Once deployed:

1. Configure the Jellyfin plugin to use the session server URL
2. Open Jellyfin in your browser
3. Start playing a movie/show
4. Click the "Watch Party" button to create or join a party
5. Share the party link with friends

## Troubleshooting

### WebSocket Connection Failed

- Ensure `ALLOWED_ORIGINS` matches your Jellyfin URL exactly (including protocol)
- If using ingress, ensure WebSocket support is enabled
- Check that the session server is accessible from the client browser

### CORS Errors

- Verify `ALLOWED_ORIGINS` includes your Jellyfin URL
- For multiple origins, use comma-separated values:
  ```yaml
  env:
    ALLOWED_ORIGINS: "https://jellyfin.example.com,http://localhost:8096"
  ```

## License

MIT License - see [OpenWatchParty](https://github.com/mhbxyz/OpenWatchParty) for details.

# OpenWatchParty Helm Chart

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

[OpenWatchParty](https://github.com/mhbxyz/OpenWatchParty) is a synchronized-playback overlay for Jellyfin: one viewer hits play and everyone in the room plays, pauses, and seeks in lockstep. This chart runs the **session server** — the Rust component that brokers rooms and relays sync events over WebSocket. The other two pieces (the Jellyfin C# plugin and the browser JS client) live inside your existing Jellyfin install. Deploy this chart when you want to host movie nights with friends who do not share your couch.

## Features

- HTTP `Ingress` and Gateway API `HTTPRoute` exposure — both pass WebSocket traffic when the controller supports it
- Single `ALLOWED_ORIGINS` env var that gates CORS to your Jellyfin URL(s)
- TCP-socket liveness/readiness probes (the session server has no HTTP health endpoint)
- HPA wiring with sensible defaults (CPU and memory thresholds) — safe to enable, this service is stateless
- `RollingUpdate` strategy by default (`maxSurge: 1`, `maxUnavailable: 0`)
- No persistence — rooms live in memory, which is the right behavior for a session broker

## Prerequisites

- Kubernetes 1.19+ (Gateway API CRDs `gateway.networking.k8s.io/v1` if `httpRoute.enabled=true`)
- Helm 3.0+
- Jellyfin 10.9+ with the OpenWatchParty plugin installed and configured to point at this service
- An Ingress controller (or Gateway) that proxies WebSockets — for example, the Cilium Gateway API, nginx with `nginx.ingress.kubernetes.io/proxy-set-headers`, or Traefik with WebSocket middleware

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install with default values

```bash
helm install openwatchparty geekxflood/openwatchparty \
  --set env.ALLOWED_ORIGINS=https://jellyfin.example.com
```

### Install with custom values

```bash
helm install openwatchparty geekxflood/openwatchparty -f values.yaml
```

### Jellyfin plugin setup

1. Add the plugin repository to Jellyfin under **Dashboard → Plugins → Repositories**:

   ```text
   https://mhbxyz.github.io/OpenWatchParty/jellyfin-plugin-repo/manifest.json
   ```

2. Install the plugin via **Dashboard → Plugins → Catalog**.
3. Add the client script in **Dashboard → General → Custom HTML**:

   ```html
   <script src="/web/plugins/openwatchparty/plugin.js"></script>
   ```

4. Configure the plugin's "Session server URL" to point at the host you exposed below (e.g. `https://watchparty.example.com`).

## Configuration

### Image

| Parameter          | Description       | Default                                          |
| ------------------ | ----------------- | ------------------------------------------------ |
| `image.repository` | Image repository  | `ghcr.io/mhbxyz/openwatchparty-session-server`   |
| `image.tag`        | Image tag         | `latest`                                         |
| `image.pullPolicy` | Image pull policy | `IfNotPresent`                                   |
| `replicaCount`     | Replica count     | `1`                                              |

### Environment

| Parameter             | Description                                          | Default                 |
| --------------------- | ---------------------------------------------------- | ----------------------- |
| `env.ALLOWED_ORIGINS` | Comma-separated CORS origins (your Jellyfin URL[s])  | `http://localhost:8096` |
| `extraEnv`            | Additional `env` entries (list of `{name, value}`)   | `[]`                    |

The session server **enforces** `ALLOWED_ORIGINS`. If it doesn't include the exact origin (scheme + host + optional port) the browser is loading Jellyfin from, the WebSocket handshake will be rejected.

### Service

| Parameter             | Description         | Default     |
| --------------------- | ------------------- | ----------- |
| `service.type`        | Service type        | `ClusterIP` |
| `service.port`        | Service port        | `3000`      |
| `service.annotations` | Service annotations | `{}`        |

### Ingress

| Parameter             | Description         | Default |
| --------------------- | ------------------- | ------- |
| `ingress.enabled`     | Enable Ingress      | `false` |
| `ingress.className`   | IngressClass name   | `""`    |
| `ingress.annotations` | Ingress annotations | `{}`    |
| `ingress.hosts`       | Host rules          | `[]`    |
| `ingress.tls`         | TLS configuration   | `[]`    |

### HTTPRoute (Gateway API)

| Parameter               | Description                                            | Default |
| ----------------------- | ------------------------------------------------------ | ------- |
| `httpRoute.enabled`     | Enable Gateway API HTTPRoute                           | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                                  | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                                       | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments (required when enabled) | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                            | `[]`    |
| `httpRoute.rules`       | Route rules (matches + backendRefs)                    | `[]`    |

Omitted `backendRefs[*].name`/`port` target this chart's service on `service.port` (3000).

### Autoscaling

| Parameter                                       | Description       | Default |
| ----------------------------------------------- | ----------------- | ------- |
| `autoscaling.enabled`                           | Enable HPA        | `false` |
| `autoscaling.minReplicas`                       | Min replicas      | `1`     |
| `autoscaling.maxReplicas`                       | Max replicas      | `10`    |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU %      | `80`    |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory %   | `80`    |

This service is stateless — autoscaling is safe. Note that an in-flight party is held in the memory of whichever replica accepted the first WebSocket; sticky routing is recommended if you scale out.

### Probes & Strategy

| Parameter                          | Description                          | Default                                  |
| ---------------------------------- | ------------------------------------ | ---------------------------------------- |
| `livenessProbe.tcpSocket.port`     | Liveness probe                       | `http` (port `3000`)                     |
| `readinessProbe.tcpSocket.port`    | Readiness probe                      | `http` (port `3000`)                     |
| `strategy.type`                    | Deployment strategy                  | `RollingUpdate`                          |
| `strategy.rollingUpdate.maxSurge`  | Max surge                            | `1`                                      |
| `strategy.rollingUpdate.maxUnavailable` | Max unavailable                 | `0`                                      |

### Resources & Scheduling

| Parameter      | Description                              | Default |
| -------------- | ---------------------------------------- | ------- |
| `resources`    | CPU/memory requests and limits           | `{}`    |
| `nodeSelector` | Node selector                            | `{}`    |
| `affinity`     | Affinity rules                           | `{}`    |
| `tolerations`  | Tolerations                              | `[]`    |

## Examples

### Ingress with WebSocket-friendly annotations

```yaml
env:
  ALLOWED_ORIGINS: "https://jellyfin.example.com"

resources:
  requests:
    cpu: 100m
    memory: 64Mi
  limits:
    cpu: 500m
    memory: 256Mi

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    # Force WS upgrade for nginx
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
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

If you self-host Jellyfin at both an internal and external URL, list both in `ALLOWED_ORIGINS`:

```yaml
env:
  ALLOWED_ORIGINS: "https://jellyfin.example.com,http://jellyfin.local:8096"
```

### Gateway API HTTPRoute with HPA

WebSockets traverse a conformant Gateway API listener without extra annotations, so this shape is shorter.

```yaml
env:
  ALLOWED_ORIGINS: "https://jellyfin.example.com"

ingress:
  enabled: false

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - watchparty.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 6
  targetCPUUtilizationPercentage: 70

resources:
  requests:
    cpu: 100m
    memory: 64Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

Cilium operators: `parentRefs[*].port` is ignored — target a listener via `sectionName`. Cross-namespace `backendRefs` require a `ReferenceGrant`.

## Persistence

None. The session server keeps rooms in memory by design — if a pod restarts, in-flight parties drop and clients reconnect to a new room. There is nothing to back up.

## Upgrading

Rolling updates are configured with `maxUnavailable: 0` so a running viewer doesn't lose connectivity during a chart upgrade. Old replicas keep their existing rooms alive until clients disconnect; new replicas accept all new rooms.

If you change `ALLOWED_ORIGINS`, restart the deployment — the value is read on startup.

## Support

- Upstream project: <https://github.com/mhbxyz/OpenWatchParty>
- Jellyfin plugin manifest: <https://mhbxyz.github.io/OpenWatchParty/jellyfin-plugin-repo/manifest.json>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. OpenWatchParty is distributed under the [MIT License](https://github.com/mhbxyz/OpenWatchParty/blob/main/LICENSE).

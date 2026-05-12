# Plex Helm Chart

![Version: 0.5.0](https://img.shields.io/badge/Version-0.5.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.42.2](https://img.shields.io/badge/AppVersion-1.42.2-informational?style=flat-square)

[Plex Media Server](https://www.plex.tv/) catalogs your local movie, TV, music, and photo files and streams them — with transcoding — to clients on every device that has a screen. This chart runs the LinuxServer.io Plex image on Kubernetes, with first-class NVIDIA GPU support so that 4K HEVC streams can be hardware-transcoded to a Roku or a phone over LTE without melting the cluster. Pair it with the rest of the *-arr stack to build a self-hosted streaming service for your household.

## Features

- HTTP `Ingress` and Gateway API `HTTPRoute` exposure
- Cloudflare Tunnel `TunnelBinding` integration for zero-trust remote access
- NVIDIA GPU passthrough: automatic `nvidia.com/gpu` resource injection, `runtimeClassName`, `NVIDIA_*` env vars
- A hard-coded 200Gi `plex-config-iscsi-pvc` (Synology iSCSI retain class) for the config / metadata cache
- Plain `volumes` / `volumeMounts` for mounting media libraries and a transcode scratch volume
- Helm test hooks under `templates/tests/` for post-install verification

## Prerequisites

- Kubernetes 1.19+ (Gateway API CRDs `gateway.networking.k8s.io/v1` if `httpRoute.enabled=true`)
- Helm 3.0+
- A storage class named `synology-csi-iscsi-retain` (used by the default config PVC), or replace that manifest with your own
- For GPU transcoding: NVIDIA GPU Operator, a working `RuntimeClass` named `nvidia` (or your override), and a node labeled `nvidia.com/gpu.present`. Optionally, GPU time-slicing for multi-pod GPU sharing.
- Existing media PVCs that the chart can mount via `volumes` / `volumeMounts` — the chart does not provision them
- Optional: cloudflare-operator if `cfTunnel.enabled=true`
- A Plex account and a fresh **claim token** from <https://www.plex.tv/claim/> for first-time setup (valid for 4 minutes)

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install with default values

```bash
helm install plex geekxflood/plex --set enabled=true
```

Note: `enabled` defaults to `false`. Until you flip it, no manifests render.

### Install with custom values

```bash
helm install plex geekxflood/plex -f values.yaml
```

### First-time server claim

Pass a fresh claim token via env so the server registers to your account on first boot:

```yaml
env:
  - name: PLEX_CLAIM
    value: "claim-XXXXXXXXXXXXXXXXXXXX"
  - name: TZ
    value: "Europe/Zurich"
```

The token expires after 4 minutes — generate it immediately before deploying.

## Configuration

### Image

| Parameter          | Description       | Default            |
| ------------------ | ----------------- | ------------------ |
| `enabled`          | Render manifests  | `false`            |
| `image.repository` | Image repository  | `linuxserver/plex` |
| `image.tag`        | Image tag         | `latest`           |
| `image.pullPolicy` | Image pull policy | `Always`           |
| `replicaCount`     | Replica count     | `1`                |

### Service

| Parameter      | Description  | Default     |
| -------------- | ------------ | ----------- |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `32400`     |

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

When `backendRefs[*].name`/`port` are omitted, the route targets this chart's service on `service.port` (32400). Cilium operators: `parentRefs[*].port` is ignored; target a listener via `sectionName`. Cross-namespace `backendRefs` require a `ReferenceGrant`.

### Cloudflare Tunnel

| Parameter            | Description                            | Default |
| -------------------- | -------------------------------------- | ------- |
| `cfTunnel.enabled`   | Render a `TunnelBinding`               | `false` |
| `cfTunnel.tunnelRef` | Reference (`{name, kind}`) to a Tunnel | `{}`    |
| `cfTunnel.subjects`  | Subjects list (defaults to this svc)   | `[]`    |

### GPU (NVIDIA)

| Parameter          | Description                          | Default  |
| ------------------ | ------------------------------------ | -------- |
| `gpu.enabled`      | Enable GPU passthrough               | `false`  |
| `gpu.runtimeClass` | RuntimeClass set on the pod          | `nvidia` |
| `gpu.count`        | `nvidia.com/gpu` request/limit count | `1`      |

When enabled, the chart sets `runtimeClassName`, adds `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=all` to the env, and merges `nvidia.com/gpu: <count>` into `resources.requests` and `resources.limits`.

### Resources, Scheduling, Storage

| Parameter             | Description                              | Default |
| --------------------- | ---------------------------------------- | ------- |
| `resources`           | CPU/memory requests and limits           | `{}`    |
| `volumes`             | Pod volumes (media, transcode, etc.)     | `[]`    |
| `volumeMounts`        | Container volume mounts                  | `[]`    |
| `nodeSelector`        | Node selector                            | `{}`    |
| `affinity`            | Affinity rules                           | `{}`    |
| `tolerations`         | Tolerations                              | `[]`    |
| `env`                 | List of `{name, value}` env vars         | `[]`    |
| `autoscaling.enabled` | Enable HPA (not recommended — see below) | `false` |

Plex stores transcoder state on the local pod; HPA across multiple replicas pointing at the same config PVC is not supported by Plex. Leave it disabled.

## Examples

### Direct-play home server (no GPU) behind Ingress

```yaml
enabled: true

image:
  repository: linuxserver/plex
  tag: latest

env:
  - name: PLEX_CLAIM
    value: "claim-XXXXXXXXXXXXXXXXXXXX"
  - name: TZ
    value: "Europe/Zurich"
  - name: PUID
    value: "1000"
  - name: PGID
    value: "100"
  - name: VERSION
    value: docker

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  hosts:
    - host: plex.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: plex-tls
      hosts:
        - plex.example.com

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 4000m
    memory: 8Gi

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: plex-config-iscsi-pvc
  - name: movies
    persistentVolumeClaim:
      claimName: movies
  - name: shows
    persistentVolumeClaim:
      claimName: tv-shows
  - name: transcode
    emptyDir:
      medium: Memory
      sizeLimit: 8Gi

volumeMounts:
  - name: config
    mountPath: /config
  - name: movies
    mountPath: /data/movies
  - name: shows
    mountPath: /data/shows
  - name: transcode
    mountPath: /transcode
```

The disabled-by-default `nginx.ingress.kubernetes.io/proxy-body-size` annotation matters — uploaded posters and library scans can exceed the default 1 MB cap.

### GPU hardware transcoding + Gateway API + Cloudflare Tunnel

```yaml
enabled: true

env:
  - name: TZ
    value: "Europe/Zurich"
  - name: PUID
    value: "1000"
  - name: PGID
    value: "100"

gpu:
  enabled: true
  runtimeClass: nvidia
  count: 1

resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 6000m
    memory: 12Gi

nodeSelector:
  nvidia.com/gpu.present: "true"

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - plex.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - weight: 1

cfTunnel:
  enabled: true
  tunnelRef:
    name: home-cluster
    kind: ClusterTunnel
  subjects:
    - name: plex
      spec:
        fqdn: plex.tunnel.example.com
        protocol: http

volumes:
  - name: config
    persistentVolumeClaim:
      claimName: plex-config-iscsi-pvc
  - name: media
    persistentVolumeClaim:
      claimName: media-library
  - name: transcode
    emptyDir:
      medium: Memory
      sizeLimit: 16Gi

volumeMounts:
  - name: config
    mountPath: /config
  - name: media
    mountPath: /data
  - name: transcode
    mountPath: /transcode
```

Once running, verify the GPU is visible inside the pod:

```bash
kubectl exec deploy/plex -- nvidia-smi
```

You should see one or more GPUs and zero MiB of FB used until the first transcode starts.

## Persistence

Plex uses several distinct paths inside the container.

| Path         | Provided by                                                  | Purpose                                                                       |
| ------------ | ------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| `/config`    | `templates/pvc.yaml` creates `plex-config-iscsi-pvc` (200Gi) | Server database, plugin state, thumbnails                                     |
| `/data/...`  | You — via `volumes` / `volumeMounts`                         | Movie / show / music libraries (read-only is fine if you scan from elsewhere) |
| `/transcode` | You — `emptyDir` or PVC                                      | Live transcoder scratch — fast NVMe or tmpfs                                  |

The default config PVC is statically named and hard-coded to `synology-csi-iscsi-retain`. If your cluster uses a different storage class, edit `templates/pvc.yaml` in a fork or pre-create the PVC out-of-band and let the chart's `volumes:` reference it.

Back up `/config` regularly — it contains all watch state, libraries, and metadata. Plex does not support multiple replicas reading the same `/config`.

## Upgrading

Plex's database migrates forward; downgrades are not supported. Before upgrading the image tag:

```bash
kubectl exec deploy/plex -- tar czf - /config > plex-config-$(date +%F).tgz
helm upgrade plex geekxflood/plex -f values.yaml
```

If you flip from CPU to GPU transcoding mid-flight, the pod restarts with the new `runtimeClassName` and `nvidia.com/gpu` resources — the next stream that needs transcoding will pick up the GPU.

## Support

- Upstream project: <https://www.plex.tv/>
- Image: <https://docs.linuxserver.io/images/docker-plex/>
- NVIDIA GPU Operator: <https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/getting-started.html>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

Chart: Apache 2.0. Plex Media Server is proprietary, distributed under the [Plex Terms of Service](https://www.plex.tv/about/privacy-legal/plex-terms-of-service/).

# transmission-openvpn Helm Chart

![Version: 0.2.1](https://img.shields.io/badge/Version-0.2.1-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 5.4.1](https://img.shields.io/badge/AppVersion-5.4.1-informational?style=flat-square)

A Helm chart for deploying [haugene/transmission-openvpn](https://github.com/haugene/docker-transmission-openvpn) on Kubernetes. This image runs the [Transmission](https://transmissionbt.com/) BitTorrent client behind an embedded OpenVPN client, so every byte of peer traffic egresses through the VPN tunnel and the pod cannot reach the public Internet if the tunnel drops (built-in kill switch via iptables). It is the standard pattern for running a torrent client privately in a homelab cluster.

The image bundles configuration profiles for dozens of commercial VPN providers (NordVPN, Mullvad, ProtonVPN, PIA, Surfshark, AirVPN, and many others). See the upstream [supported providers list](https://haugene.github.io/docker-transmission-openvpn/supported-providers/) for the exact `OPENVPN_PROVIDER` values.

## Features

- Single-container deployment of Transmission + OpenVPN with chart-managed image, replicas, resources, and pod metadata.
- Environment variables via `env` (literal) and `envFrom` (`Secret` / `ConfigMap` references) — the typical way to inject `OPENVPN_USERNAME` / `OPENVPN_PASSWORD` from a `Secret`.
- Pluggable `runtimeClassName` (e.g., `gvisor`, `kata`) via `runtime.enabled` + `runtime.name`.
- Init containers via `initContainers` for pre-flight steps (e.g., DNS/firewall checks).
- HTTP service on port 9091 (Transmission RPC + web UI) with optional `Ingress`.
- Optional Gateway API `HTTPRoute` for vanilla Kubernetes Gateway implementations.
- Optional Cloudflare Tunnel `TunnelBinding` for zero-trust public exposure.
- Horizontal Pod Autoscaler template (note: scaling a torrent client is unusual; keep `replicaCount: 1` for normal use).
- Arbitrary `volumes` / `volumeMounts` for `/data`, `/config`, watched folders, and downloads.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- **Pod-level networking privileges.** The OpenVPN client needs to create a `tun` device. In practice this requires either:
  - `securityContext.capabilities.add: ["NET_ADMIN"]` on the container, and the kernel `/dev/net/tun` device available on the node, **or**
  - `securityContext.privileged: true` (simplest, broadest).
- A Kubernetes `Secret` holding `OPENVPN_USERNAME` and `OPENVPN_PASSWORD` (do not commit these to `values.yaml`).
- A PVC (or other volume) mounted at `/data` for downloads and Transmission state.
- A PodSecurityAdmission / PSP / OPA policy that permits the required capabilities in your namespace.

> Some Kubernetes distributions (OpenShift, GKE Autopilot) restrict `NET_ADMIN` and `privileged`. Verify policy before deploying.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install transmission geekxflood/transmission-openvpn
```

### Install with custom values

```bash
helm install transmission geekxflood/transmission-openvpn -f values.yaml
```

## Configuration

### Global Parameters

| Parameter      | Description                         | Default |
| -------------- | ----------------------------------- | ------- |
| `enabled`      | Enable/disable the chart deployment | `false` |
| `replicaCount` | Number of replicas (keep at 1)      | `1`     |

### Image Parameters

| Parameter          | Description        | Default                       |
| ------------------ | ------------------ | ----------------------------- |
| `image.repository` | Image repository   | `haugene/transmission-openvpn` |
| `image.pullPolicy` | Image pull policy  | `IfNotPresent`                |
| `image.tag`        | Image tag          | `"5.4.1"`                     |
| `imagePullSecrets` | Image pull secrets | `[]`                          |

### Service Account Parameters

| Parameter                    | Description                     | Default |
| ---------------------------- | ------------------------------- | ------- |
| `serviceAccount.create`      | Create service account          | `true`  |
| `serviceAccount.automount`   | Automount service account token | `true`  |
| `serviceAccount.annotations` | Service account annotations     | `{}`    |
| `serviceAccount.name`        | Service account name override   | `""`    |

### Pod Parameters

| Parameter            | Description                | Default |
| -------------------- | -------------------------- | ------- |
| `nameOverride`       | Override chart name        | `""`    |
| `fullnameOverride`   | Override full release name | `""`    |
| `podAnnotations`     | Pod annotations            | `{}`    |
| `podLabels`          | Pod labels                 | `{}`    |
| `podSecurityContext` | Pod security context       | `{}`    |
| `securityContext`    | Container security context (set capabilities or privileged here) | `{}`    |

### Runtime Class

| Parameter        | Description                            | Default |
| ---------------- | -------------------------------------- | ------- |
| `runtime.enabled`| Set `runtimeClassName` on the pod      | `false` |
| `runtime.name`   | Runtime class name (e.g., `gvisor`)    | `""`    |

### Init Containers

| Parameter        | Description                                                  | Default |
| ---------------- | ------------------------------------------------------------ | ------- |
| `initContainers` | Raw `initContainers` array injected into the pod template    | `[]`    |

### Environment Variables

| Parameter | Description                                          | Default |
| --------- | ---------------------------------------------------- | ------- |
| `env`     | Literal env vars (`OPENVPN_PROVIDER`, `LOCAL_NETWORK`, ...) | `[]`    |
| `envFrom` | Refs to `Secret` (`type: secret`) or `ConfigMap` (`type: configmap`) by `name` | `[]`    |

The `envFrom` block uses a chart-specific shape (each entry has `type` and `name`) — the template rewrites it into real `secretRef` / `configMapRef` entries. See the deployment template for the exact contract.

### Service Parameters

| Parameter      | Description                          | Default     |
| -------------- | ------------------------------------ | ----------- |
| `service.type` | Service type                         | `ClusterIP` |
| `service.port` | Transmission RPC / web UI port       | `9091`      |

### Ingress Parameters

| Parameter             | Description                 | Default                          |
| --------------------- | --------------------------- | -------------------------------- |
| `ingress.enabled`     | Enable Ingress              | `false`                          |
| `ingress.className`   | Ingress class name          | `""`                             |
| `ingress.annotations` | Ingress annotations         | `{}`                             |
| `ingress.hosts`       | Ingress hosts configuration | `chart-example.local` (override) |
| `ingress.tls`         | Ingress TLS configuration   | `[]`                             |

### HTTPRoute (Gateway API) Parameters

| Parameter               | Description                                            | Default |
| ----------------------- | ------------------------------------------------------ | ------- |
| `httpRoute.enabled`     | Enable Gateway API HTTPRoute                           | `false` |
| `httpRoute.annotations` | HTTPRoute annotations                                  | `{}`    |
| `httpRoute.labels`      | HTTPRoute labels                                       | `{}`    |
| `httpRoute.parentRefs`  | Gateway / Listener attachments (required when enabled) | `[]`    |
| `httpRoute.hostnames`   | Hostnames the route matches                            | `[]`    |
| `httpRoute.rules`       | Route rules; `backendRefs` default to this service     | `[]`    |

### Cloudflare Tunnel Parameters

| Parameter            | Description                       | Default |
| -------------------- | --------------------------------- | ------- |
| `cfTunnel.enabled`   | Enable Cloudflare Tunnel binding  | `false` |
| `cfTunnel.tunnelRef` | Tunnel reference (`name`, `kind`) | `{}`    |
| `cfTunnel.subjects`  | Tunnel subjects                   | `{}`    |

### Autoscaling Parameters

| Parameter                                       | Description                      | Default |
| ----------------------------------------------- | -------------------------------- | ------- |
| `autoscaling.enabled`                           | Enable horizontal pod autoscaler | `false` |
| `autoscaling.minReplicas`                       | Minimum replicas                 | `1`     |
| `autoscaling.maxReplicas`                       | Maximum replicas                 | `100`   |
| `autoscaling.targetCPUUtilizationPercentage`    | Target CPU utilization           | `80`    |
| `autoscaling.targetMemoryUtilizationPercentage` | Target memory utilization        | `80`    |

### Storage & Scheduling

| Parameter      | Description                  | Default |
| -------------- | ---------------------------- | ------- |
| `volumes`      | Additional volumes           | `[]`    |
| `volumeMounts` | Additional volume mounts     | `[]`    |
| `resources`    | Resource requests and limits | `{}`    |
| `nodeSelector` | Node selector                | `{}`    |
| `tolerations`  | Tolerations                  | `[]`    |
| `affinity`     | Affinity rules               | `{}`    |

## Examples

### Mullvad with NET_ADMIN, secret-backed credentials, and persistence

Create the credential `Secret` first (`OPENVPN_USERNAME` is your Mullvad account number, `OPENVPN_PASSWORD` is literally `m` per Mullvad docs):

```bash
kubectl create secret generic transmission-vpn-credentials \
  --from-literal=OPENVPN_USERNAME='1234567890123456' \
  --from-literal=OPENVPN_PASSWORD='m'
```

```yaml
enabled: true

securityContext:
  capabilities:
    add:
      - NET_ADMIN

env:
  - name: OPENVPN_PROVIDER
    value: "MULLVAD"
  - name: OPENVPN_CONFIG
    value: "se_sto"               # Sweden / Stockholm
  - name: LOCAL_NETWORK
    value: "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
  - name: TRANSMISSION_RPC_USERNAME
    value: "admin"
  - name: TRANSMISSION_RPC_PASSWORD
    value: "change-me"
  - name: TRANSMISSION_RPC_HOST_WHITELIST_ENABLED
    value: "false"
  - name: PUID
    value: "1000"
  - name: PGID
    value: "100"
  - name: TZ
    value: "Europe/Paris"

envFrom:
  - type: secret
    name: transmission-vpn-credentials

volumes:
  - name: data
    persistentVolumeClaim:
      claimName: transmission-data
  - name: dev-tun
    hostPath:
      path: /dev/net/tun

volumeMounts:
  - name: data
    mountPath: /data
  - name: dev-tun
    mountPath: /dev/net/tun

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: transmission.example.com
      paths:
        - path: /
          pathType: Prefix
```

`LOCAL_NETWORK` is critical: without it, the kill switch blocks the cluster pod network and the web UI becomes unreachable from inside the cluster. Set it to the union of your pod, service, and cluster node CIDRs.

### NordVPN with privileged mode and a fixed peer port

```yaml
enabled: true

securityContext:
  privileged: true

env:
  - name: OPENVPN_PROVIDER
    value: "NORDVPN"
  - name: NORDVPN_COUNTRY
    value: "CH"
  - name: NORDVPN_CATEGORY
    value: "P2P"
  - name: NORDVPN_PROTOCOL
    value: "tcp"
  - name: LOCAL_NETWORK
    value: "10.0.0.0/8"
  - name: TRANSMISSION_PEER_PORT
    value: "51413"
  - name: TRANSMISSION_PEER_PORT_RANDOM_ON_START
    value: "false"

envFrom:
  - type: secret
    name: transmission-vpn-credentials

volumes:
  - name: data
    persistentVolumeClaim:
      claimName: transmission-data

volumeMounts:
  - name: data
    mountPath: /data
```

### Custom OpenVPN config (unsupported provider)

If your provider is not in the bundled list, mount a `.ovpn` file and set `OPENVPN_PROVIDER=CUSTOM`:

```yaml
env:
  - name: OPENVPN_PROVIDER
    value: "CUSTOM"
  - name: OPENVPN_CONFIG
    value: "my-provider"
  - name: LOCAL_NETWORK
    value: "10.0.0.0/8"

envFrom:
  - type: secret
    name: transmission-vpn-credentials

volumes:
  - name: ovpn
    secret:
      secretName: transmission-ovpn-config
  - name: data
    persistentVolumeClaim:
      claimName: transmission-data

volumeMounts:
  - name: ovpn
    mountPath: /etc/openvpn/custom
  - name: data
    mountPath: /data
```

## Persistence

The image expects a single primary volume at `/data` which holds:

- `/data/completed` — completed downloads
- `/data/incomplete` — in-progress downloads
- `/data/watch` — watch directory (drop `.torrent` files in)
- `/data/transmission-home` — Transmission's `settings.json`, resume files, and torrent metadata

Mount this through `volumes` / `volumeMounts`. The chart does not declare a built-in persistence block — bring your own `PersistentVolumeClaim`. For RWO storage, scale to zero before upgrading, or use RWX storage so the new pod can attach before the old one terminates.

## Integration notes

### As a download client in Sonarr / Radarr

In Sonarr/Radarr, add a Transmission client under **Settings -> Download Clients**:

- Host: `transmission-openvpn.<namespace>.svc.cluster.local`
- Port: `9091`
- URL Base: `/transmission/` (Transmission's default RPC base)
- Username / Password: the `TRANSMISSION_RPC_USERNAME` / `TRANSMISSION_RPC_PASSWORD` you set in `env`
- Category: e.g., `tv-sonarr`, `movies-radarr`

Mount the same `/data/completed` path into the *arr deployments so they can hard-link/move completed downloads without rewriting the file.

### Verifying the VPN is up

After install:

```bash
kubectl exec deploy/transmission -- curl -fsS https://am.i.mullvad.net/json
```

The reported public IP must match your VPN provider, not your cluster egress IP. If the command hangs or fails, the OpenVPN tunnel didn't come up — check `kubectl logs` for `Initialization Sequence Completed`.

## Upgrading

### To 0.2.1

- Documentation refresh; behaviour unchanged.

### To 0.2.0

- Added Gateway API `HTTPRoute` and Cloudflare Tunnel `TunnelBinding` templates.

## Uninstallation

```bash
helm uninstall transmission
```

Manually delete any PVCs or `Secret` resources created out-of-band.

## Support

- Upstream image: <https://github.com/haugene/docker-transmission-openvpn>
- Supported VPN providers: <https://haugene.github.io/docker-transmission-openvpn/supported-providers/>
- Transmission project: <https://transmissionbt.com/>
- Chart Repository Issues: <https://github.com/geekxflood/helm-charts/issues>

## License

This Helm chart is licensed under the Apache License 2.0. Transmission is licensed under GPL/MIT; the haugene image carries its own [GPL-3.0 license](https://github.com/haugene/docker-transmission-openvpn/blob/master/LICENSE).

# bench Helm Chart

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

A Helm chart for deploying [bench](https://github.com/geekxflood/bench) on Kubernetes. bench is a tiny, static **WoW raid bench roller**: enter your raiders, pick how many to bench, and a d20 roll decides who sits out — then copy the result straight into Discord.

The app is entirely client-side and is served by an unprivileged `nginx` container (`ghcr.io/geekxflood/bench`) listening on port `8080`. It is stateless, has no config, and stores nothing.

## Features

- Stateless deployment of the static site with configurable replicas, resources, probes, and pod metadata.
- HTTP service on port 8080 with a `/healthz` endpoint wired to liveness/readiness probes.
- Optional `Ingress`.
- Optional Gateway API `HTTPRoute` (used here with the Cilium Gateway for `bench.local.geekxflood.io`).
- Optional Cloudflare Tunnel `TunnelBinding` (used here for the public `bench.geekxflood.io`).
- HPA template for horizontal scaling.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+

bench does **not** require persistent storage.

## Installation

### Add the Helm repository

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

### Install the chart

```bash
helm install bench geekxflood/bench --set enabled=true
```

## Public exposure (geekxflood cluster)

```yaml
enabled: true

httpRoute:
  enabled: true
  parentRefs:
    - name: cilium-gateway
      namespace: kube-system
      sectionName: https
  hostnames:
    - bench.local.geekxflood.io
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - {}

cfTunnel:
  enabled: true
  tunnelRef:
    name: gxf-cluster-tunnel
    kind: ClusterTunnel
  subjects:
    - name: bench
      spec:
        spec:
          fqdn: bench.geekxflood.io
          protocol: http
```

## Values

| Key | Default | Description |
|---|---|---|
| `image.repository` | `ghcr.io/geekxflood/bench` | Container image. |
| `image.tag` | `""` (chart `appVersion`) | Image tag. |
| `replicaCount` | `1` | Number of replicas. |
| `service.port` | `8080` | Service / container port. |
| `httpRoute.enabled` | `false` | Enable a Gateway API `HTTPRoute`. |
| `cfTunnel.enabled` | `false` | Enable a Cloudflare `TunnelBinding`. |
| `ingress.enabled` | `false` | Enable a legacy `Ingress`. |
| `autoscaling.enabled` | `false` | Enable an HPA. |

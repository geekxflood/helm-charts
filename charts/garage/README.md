# garage

S3-compatible object store for small self-hosted geo-distributed deployments

## Introduction

This chart bootstraps a [garage](https://github.com/geekxflood/helm-charts/tree/main/charts/garage) deployment on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Installation

```bash
helm install garage ./charts/garage
```

## Configuration

The following table lists the configurable parameters of the garage chart and their default values.
Please refer to `values.yaml` for the full list of configuration options.

## HTTPRoute (Gateway API)

This chart can expose Garage's S3 API and S3 web endpoints via vanilla Kubernetes Gateway API `HTTPRoute` objects in addition to (or instead of) the existing Ingress objects. The HTTPRoute templates work with any conformant controller — Cilium Gateway API, Istio, Envoy Gateway.

The route layout mirrors the Ingress one: a master toggle `httpRoute.enabled` plus two independent sub-toggles for the two Garage services:

- `httpRoute.s3.api` — S3 API endpoint (backend defaults to `<fullname>` on `service.s3.api.port`)
- `httpRoute.s3.web` — S3 web/static-website endpoint (backend defaults to `<fullname>` on `service.s3.web.port`)

Each sub-route is only rendered when **both** `httpRoute.enabled=true` **and** the inner `httpRoute.s3.<api|web>.enabled=true`. Omit `backendRefs[*].name` / `port` to fall through to those defaults.

```yaml
# Disable legacy Ingress and route via Gateway API
ingress:
  s3:
    api:
      enabled: false
    web:
      enabled: false

httpRoute:
  enabled: true
  s3:
    # S3 API — bucket put/get, signed URLs, etc.
    api:
      enabled: true
      parentRefs:
        - name: cilium-gateway
          namespace: gateway-system
          # sectionName: https
      hostnames:
        - s3.example.com
        - "*.s3.example.com"
      rules:
        - matches:
            - path:
                type: PathPrefix
                value: /
          backendRefs:
            - weight: 1
    # S3 web — static website hosting
    web:
      enabled: true
      parentRefs:
        - name: cilium-gateway
          namespace: gateway-system
      hostnames:
        - "*.web.example.com"
        - s3-web.example.com
      rules:
        - matches:
            - path:
                type: PathPrefix
                value: /
          backendRefs:
            - weight: 1
```

Notes for Cilium operators:

- `parentRefs[*].port` is ignored — target a Gateway listener via `sectionName`.
- Cross-namespace `backendRefs` require a `ReferenceGrant` in the namespace where Garage runs.
- TLS is terminated by the Gateway listener, not by the route — no `tls` block here.
- The HTTPRoute and Ingress objects can coexist; migrate per-endpoint by disabling the matching `ingress.s3.<api|web>.enabled` and enabling `httpRoute.s3.<api|web>.enabled`.

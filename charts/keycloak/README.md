# keycloak

A Helm chart for Keycloak - Open Source Identity and Access Management

## Introduction

This chart bootstraps a [keycloak](https://github.com/geekxflood/helm-charts/tree/main/charts/keycloak) deployment on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Installation

```bash
helm install keycloak ./charts/keycloak
```

## Configuration

The following table lists the configurable parameters of the keycloak chart and their default values.
Please refer to `values.yaml` for the full list of configuration options.

## HTTPRoute (Gateway API)

This chart can expose Keycloak via vanilla Kubernetes Gateway API `HTTPRoute` objects in addition to (or instead of) the existing public/admin Ingress objects. The HTTPRoute templates work with any conformant controller — Cilium Gateway API, Istio, Envoy Gateway.

The route layout mirrors the Ingress one: a master toggle `httpRoute.enabled` plus two independent sub-toggles:

- `httpRoute.public` — authentication endpoints (typically exposed publicly via Gateway)
- `httpRoute.admin` — admin console (typically attached to an internal Gateway)

Each sub-route is only rendered when **both** `httpRoute.enabled=true` **and** the inner `httpRoute.<sub>.enabled=true`. Backend `backendRefs` default to the chart's `<fullname>-service` (created by the Keycloak Operator) on `service.port` (default `8080`), so omitted backend fields just work.

```yaml
service:
  port: 8080

# Disable legacy Ingress and route via Gateway API
ingress:
  enabled: false

httpRoute:
  enabled: true

  # Public route — auth endpoints, attach to your public Gateway
  public:
    enabled: true
    parentRefs:
      - name: cilium-gateway
        namespace: gateway-system
        # sectionName: https
    hostnames:
      - auth.example.com
    rules:
      - matches:
          - path:
              type: PathPrefix
              value: /realms
          - path:
              type: PathPrefix
              value: /resources
          - path:
              type: PathPrefix
              value: /js
        backendRefs:
          - weight: 1

  # Admin route — admin console, attach to an internal-only Gateway
  admin:
    enabled: true
    parentRefs:
      - name: cilium-gateway-internal
        namespace: gateway-system
    hostnames:
      - auth.local.example.com
    rules:
      - matches:
          - path:
              type: PathPrefix
              value: /admin
          - path:
              type: PathPrefix
              value: /realms/master/admin
        backendRefs:
          - weight: 1
```

Notes for Cilium operators:

- `parentRefs[*].port` is ignored — target a Gateway listener via `sectionName`.
- Cross-namespace `backendRefs` require a `ReferenceGrant` in the namespace where the Keycloak service runs.
- The HTTPRoute and Ingress objects can coexist; migrate per-route by disabling the matching `ingress.<sub>.enabled` and enabling `httpRoute.<sub>.enabled`.

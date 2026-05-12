# OAuth2 Proxy Helm Chart

![Version: 1.0.2](https://img.shields.io/badge/Version-1.0.2-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 7.15.2](https://img.shields.io/badge/AppVersion-7.15.2-informational?style=flat-square)

A Helm chart that deploys [OAuth2 Proxy](https://oauth2-proxy.github.io/oauth2-proxy/) — a reverse-proxy authentication gateway that authenticates upstream HTTP applications against an OIDC / OAuth 2.0 provider (Keycloak, Google, GitHub, etc.). The chart renders a `Deployment`, `Service`, `ServiceAccount`, and a `ConfigMap` with the full proxy configuration.

This chart targets the common self-hosted pattern of running oauth2-proxy as `auth-request` provider in front of applications that lack native SSO (the *arr stack, Plex tooling, internal dashboards). It is preconfigured for the `keycloak-oidc` provider but works with any provider supported by the upstream binary.

## Features

- Single-replica or HA `Deployment` with pod anti-affinity by hostname
- `keycloak-oidc` provider preconfigured; switch `config.provider` for any other supported provider
- Client secret and cookie secret loaded from existing Kubernetes `Secret`s (no plaintext in values)
- Cookie domain / SameSite / refresh / expire fully tunable
- Upstream and redirect URLs settable per release for per-app deployments
- Email and `whitelistDomains` allowlists
- `passAccessToken`, `passAuthorizationHeader`, `setXAuthRequest` toggles for upstream identity propagation
- Read-only root filesystem and `runAsNonRoot` by default
- Liveness/readiness probes on `/ping`, optional `HorizontalPodAutoscaler`

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- An OIDC provider (typically a [Keycloak](../keycloak) realm) with an OIDC client created for this proxy
- Two pre-created Kubernetes `Secret`s in the release namespace:
  - one with the **client secret** (default: `oauth2-proxy-client-secret`, key `client-secret`)
  - one with the **cookie secret** (default: `oauth2-proxy-cookie-secret`, key `cookie-secret`); generate with `openssl rand -base64 32`
- An ingress controller in front of oauth2-proxy and the upstream app (nginx, Cilium, Envoy Gateway, …) capable of `auth-request` forwarding

## Installation

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm install oauth2-proxy geekxflood/oauth2-proxy
helm install oauth2-proxy geekxflood/oauth2-proxy -f values.yaml
```

Pre-create the secrets first:

```bash
kubectl create secret generic oauth2-proxy-client-secret \
  --from-literal=client-secret="$(read -r -p 'Client secret: ' s && echo "$s")"

kubectl create secret generic oauth2-proxy-cookie-secret \
  --from-literal=cookie-secret="$(openssl rand -base64 32 | tr -d '\n')"
```

## Configuration

### Deployment

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Replica count | `2` |
| `image.repository` | Container image | `quay.io/oauth2-proxy/oauth2-proxy` |
| `image.tag` | Image tag | `v7.15.2` |
| `resources.*` | CPU / memory requests / limits | see `values.yaml` |
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` / `maxReplicas` | HPA bounds | `2` / `5` |

### Service & probes

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` / `targetPort` | Service / target port | `4180` |
| `livenessProbe` / `readinessProbe` | HTTP probes on `/ping` | see `values.yaml` |

### OIDC provider

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.provider` | Provider type | `keycloak-oidc` |
| `config.oidcIssuerUrl` | Issuer URL (`https://<host>/realms/<realm>`) | `https://keycloak.example.com/realms/myrealm` |
| `config.clientID` | OIDC client ID | `myapp` |
| `config.clientSecretRef.name` / `.key` | Secret reference for client secret | `oauth2-proxy-client-secret` / `client-secret` |
| `config.cookieSecretRef.name` / `.key` | Secret reference for cookie secret | `oauth2-proxy-cookie-secret` / `cookie-secret` |
| `config.redirectUrl` | OAuth2 callback URL (`https://<app>/oauth2/callback`) | `""` |

### Cookies & session

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.cookieName` | Cookie name | `_oauth2_proxy` |
| `config.cookieDomain` | Cookie domain (lead dot for wildcard) | `.example.com` |
| `config.cookieSecure` | `Secure` flag | `true` |
| `config.cookieHttpOnly` | `HttpOnly` flag | `true` |
| `config.cookieSameSite` | SameSite policy | `lax` |
| `config.cookieExpire` | Cookie lifetime | `168h` |
| `config.cookieRefresh` | Refresh interval | `1h` |

### Access control

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.emailDomains` | Allowed email domains (`*` = all) | `["*"]` |
| `config.whitelistDomains` | Redirect allowlist | `[".example.com"]` |
| `config.skipAuthRoutes` | Regex paths to bypass auth | `[]` |
| `config.upstreams` | Upstream URLs (typically empty when used in `auth-request` mode) | `[]` |

### Header / token propagation

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.reverseProxy` | Trust reverse-proxy headers | `true` |
| `config.realClientIPHeader` | Real client IP header | `X-Forwarded-For` |
| `config.passAccessToken` | Forward access token to upstream | `true` |
| `config.passAuthorizationHeader` | Forward `Authorization` header | `true` |
| `config.setAuthorizationHeader` | Set `Authorization` header from token | `true` |
| `config.setXAuthRequest` | Set `X-Auth-Request-*` headers | `true` |

### Logging

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.logLevel` | Log level | `info` |
| `config.standardLogging` / `requestLogging` / `authLogging` | Log channel toggles | `true` |

## Examples

### Auth-request mode in front of an *arr app (nginx ingress)

This is the canonical "protect an app that has no SSO" pattern. The oauth2-proxy `Service` is reached via the ingress controller's `auth-request` flow.

```yaml
config:
  provider: keycloak-oidc
  oidcIssuerUrl: https://auth.example.com/realms/gxf
  clientID: sonarr
  clientSecretRef:
    name: oauth2-proxy-client-secret
    key: client-secret
  cookieSecretRef:
    name: oauth2-proxy-cookie-secret
    key: cookie-secret
  cookieDomain: ".example.com"
  redirectUrl: https://sonarr.example.com/oauth2/callback
  whitelistDomains:
    - ".example.com"
  emailDomains:
    - "*"
  upstreams: []  # auth-request only; ingress forwards to the real upstream
```

Then on the upstream app's ingress:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "https://$host/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
    nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User,X-Auth-Request-Email"
```

Expose `/oauth2/` paths on the same hostname (a separate `Ingress` pointing at the `oauth2-proxy` service on port `4180`).

### Group-restricted access with HA + autoscaling

```yaml
replicaCount: 3

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 8
  targetCPUUtilizationPercentage: 70

config:
  provider: keycloak-oidc
  oidcIssuerUrl: https://auth.example.com/realms/gxf
  clientID: dashboards
  cookieDomain: ".internal.example.com"
  redirectUrl: https://grafana.internal.example.com/oauth2/callback
  emailDomains:
    - "example.com"
  whitelistDomains:
    - ".internal.example.com"
  passAccessToken: true
  setAuthorizationHeader: true
  setXAuthRequest: true
  skipAuthRoutes:
    - "^/api/health$"
    - "^/metrics$"
```

## Persistence

None. oauth2-proxy is stateless — sessions are signed cookies. Make sure all replicas share the same `cookieSecret` (they do by default via the referenced `Secret`).

## Integration notes

- **In front of apps without OIDC**, deploy one `oauth2-proxy` per protected upstream (different `clientID`, `redirectUrl`, `cookieDomain`). Wire the upstream app's ingress with `nginx.ingress.kubernetes.io/auth-url` (or the Gateway API equivalent for your controller) to forward auth subrequests to `https://<app-host>/oauth2/auth`.
- **Shared instance** (one proxy for many apps) is supported via `config.upstreams` and a wildcard `cookieDomain` (e.g. `.example.com`) but requires each app's hostname to be a child of that domain.
- **Keycloak client config**: enable `Standard Flow`, set `Valid Redirect URIs` to `https://<app-host>/oauth2/callback`, set `Web Origins` to `+`, set `Access Type` to `confidential`, and copy the generated client secret into the `oauth2-proxy-client-secret` Secret.
- **Cookies require TLS** when `cookieSecure: true`. Terminate TLS at the ingress / Gateway.
- **Token propagation**: when `setAuthorizationHeader: true`, the upstream sees a valid Bearer token. Many apps (Grafana, ArgoCD) can consume this directly for SSO.

## Upgrading

- Cookie format changes between major oauth2-proxy versions invalidate existing sessions — expect users to re-authenticate after upgrades.
- When rotating `cookieSecret`, restart all replicas simultaneously to avoid mixed-fleet decryption failures.

## Support

- Upstream: <https://oauth2-proxy.github.io/oauth2-proxy/> · <https://github.com/oauth2-proxy/oauth2-proxy>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

- Chart: Apache License 2.0
- OAuth2 Proxy: [MIT License](https://github.com/oauth2-proxy/oauth2-proxy/blob/master/LICENSE)

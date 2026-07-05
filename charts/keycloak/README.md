# Keycloak Helm Chart

![Version: 0.13.0](https://img.shields.io/badge/Version-0.13.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 26.6.1](https://img.shields.io/badge/AppVersion-26.6.1-informational?style=flat-square)

A Helm chart that deploys [Keycloak](https://www.keycloak.org/) — the open-source OIDC, OAuth 2.0, and SAML 2.0 identity and access management platform — via the [Keycloak Operator](https://www.keycloak.org/operator/installation). This chart renders a `Keycloak` Custom Resource and supporting resources (ingress, HTTPRoute, realm import, custom theme, OpenBao auth/secret, admin setup job). It does **not** install the operator itself or the PostgreSQL database — both are prerequisites.

Typical usage in a self-hosted stack: Keycloak is the SSO anchor that issues tokens consumed by [oauth2-proxy](../oauth2-proxy) sitting in front of apps that lack native OIDC (the *arr stack, dashboards), and natively by apps like Jellyfin via the SSO plugin.

## Features

- Deploys a `Keycloak` CR (CRD: `k8s.keycloak.org/v2alpha1`) for management by the Keycloak Operator
- Uses an external PostgreSQL backend (e.g. [postgres-ha](../postgres-ha) cluster) with credentials read from an existing `Secret`
- Optional dynamic database credentials via the [database-provisioner](../database-provisioner) pattern
- Pluggable hostname v2 configuration (`strict`, `backchannelDynamic`, separate admin hostname)
- Provider JARs (e.g. `keycloak-discord`) downloaded at startup via init containers
- Dual ingress / HTTPRoute (Gateway API) — separate public and admin routes
- Realm import via `KeycloakRealmImport` CR with authentication flows and authenticator configs
- Optional admin setup job that promotes a permanent admin from the bootstrap credentials and removes the "temporary admin" warning
- Optional custom theme ConfigMap (error page with configurable redirect)
- OpenBao (Vault Secrets Operator) integration: `VaultAuth` + `VaultStaticSecret` references for credentials
- Pod anti-affinity by hostname and Prometheus-friendly metrics endpoint

## Prerequisites

- Kubernetes 1.24+
- Helm 3.0+
- [Keycloak Operator](https://www.keycloak.org/operator/installation) installed (the chart only renders the `Keycloak` CR; the operator reconciles it)
- A reachable PostgreSQL instance and a `Secret` containing `username` / `password` keys (see `postgresql.existingSecret`). Use the [postgres-ha](../postgres-ha) chart for an HA backend
- For `httpRoute`: the Gateway API CRDs installed and a working Gateway (Cilium Gateway API, Istio, Envoy Gateway, etc.)
- For `openbao.enabled`: [Vault Secrets Operator](https://github.com/hashicorp/vault-secrets-operator) and a reachable OpenBao/Vault cluster
- For `adminSetupJob.enabled`: a pre-populated `Secret` containing permanent admin credentials (typically materialise from OpenBao)

## Installation

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm install keycloak geekxflood/keycloak
helm install keycloak geekxflood/keycloak -f values.yaml
```

The chart deploys nothing useful until you set `keycloak.hostname`, point `postgresql.existingSecret` at a real credential `Secret`, and either enable an `ingress.*` or `httpRoute.*` route.

## Configuration

### Operator & server

| Parameter                              | Description                                                      | Default         |
| -------------------------------------- | ---------------------------------------------------------------- | --------------- |
| `operator.enabled`                     | Render the `Keycloak` CR                                         | `true`          |
| `operator.http.enabled`                | Allow plain HTTP (terminate TLS at proxy)                        | `true`          |
| `operator.http.tlsSecret`              | Secret with `tls.crt`/`tls.key` for in-pod TLS                   | `""`            |
| `operator.hostname.strict`             | Disable dynamic hostname resolution (hostname v2)                | `false`         |
| `operator.hostname.backchannelDynamic` | Enable dynamic backchannel URLs                                  | `false`         |
| `operator.hostname.admin`              | Separate admin hostname (e.g. `https://auth-admin.example.com`)  | `""`            |
| `operator.additionalOptions`           | Free-form Keycloak server options                                | `[]`            |
| `replicaCount`                         | Keycloak replicas                                                | `1`             |
| `clusterDomain`                        | Cluster DNS domain for internal FQDNs (DB host, JGroups DNS)     | `cluster.local` |

### Keycloak server settings

| Parameter                         | Description                                       | Default               |
| --------------------------------- | ------------------------------------------------- | --------------------- |
| `keycloak.hostname`               | Public hostname (e.g. `https://auth.example.com`) | `""`                  |
| `keycloak.features`               | Feature flags (e.g. `["preview"]`)                | `[]`                  |
| `keycloak.providers`              | External provider JARs to download at startup     | `[]`                  |
| `keycloak.proxy.enabled`          | Trust reverse-proxy headers                       | `true`                |
| `keycloak.proxy.mode`             | Proxy mode (`xforwarded`, `edge`, `passthrough`)  | `xforwarded`          |
| `keycloak.health.enabled`         | Enable `/health` endpoints                        | `true`                |
| `keycloak.metrics.enabled`        | Enable Prometheus metrics                         | `true`                |
| `keycloak.cache.type` / `.stack`  | Infinispan cache settings                         | `ispn` / `kubernetes` |
| `keycloak.extraEnv` / `extraArgs` | Extra env vars / CLI args                         | `[]`                  |

### Admin credentials

| Parameter                  | Description                                            | Default                      |
| -------------------------- | ------------------------------------------------------ | ---------------------------- |
| `admin.username`           | Bootstrap admin username                               | `admin`                      |
| `admin.password`           | Bootstrap admin password (use existing secret instead) | `change_me_password`         |
| `admin.existingSecret`     | Use an existing `Secret` for admin credentials         | `true`                       |
| `admin.existingSecretName` | Name of admin credential `Secret`                      | `keycloak-admin-credentials` |

### Database

| Parameter                                               | Description                                                                  | Default                   |
| ------------------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------- |
| `postgresql.provisionDatabase`                          | Render `Database` CR for the [database-provisioner](../database-provisioner) | `true`                    |
| `postgresql.useDynamicCredentials`                      | Use OpenBao-issued credentials                                               | `true`                    |
| `postgresql.clusterName`                                | Target CloudNativePG `Cluster` name                                          | `postgres-ha`             |
| `postgresql.databaseNamespace`                          | Namespace of the cluster                                                     | `database`                |
| `postgresql.database`                                   | Database name                                                                | `keycloak`                |
| `postgresql.username`                                   | Database role                                                                | `keycloak`                |
| `postgresql.existingSecret.name`                        | Secret containing DB credentials                                             | `keycloak-db-credentials` |
| `postgresql.existingSecret.usernameKey` / `passwordKey` | Keys within the secret                                                       | `username` / `password`   |
| `postgresql.reclaimPolicy`                              | `retain` / `delete` for the `Database` CR                                    | `retain`                  |

### Ingress (public + admin)

| Parameter                                      | Description                            | Default |
| ---------------------------------------------- | -------------------------------------- | ------- |
| `ingress.enabled`                              | Master ingress toggle                  | `false` |
| `ingress.public.enabled`                       | Public-facing ingress (auth endpoints) | `false` |
| `ingress.public.hosts` / `tls` / `annotations` | Standard ingress wiring                | `[]`    |
| `ingress.admin.enabled`                        | Admin console ingress (internal only)  | `false` |
| `ingress.admin.hosts` / `tls` / `annotations`  | Standard ingress wiring                | `[]`    |

The public ingress exposes `/realms`, `/resources`, `/js`; the admin ingress exposes `/admin` and `/realms/master/admin`. Keep the admin ingress off public networks.

### HTTPRoute (Gateway API)

| Parameter            | Description                                       | Default |
| -------------------- | ------------------------------------------------- | ------- |
| `httpRoute.enabled`  | Master HTTPRoute toggle                           | `false` |
| `httpRoute.public.*` | Public route (`parentRefs`, `hostnames`, `rules`) | `[]`    |
| `httpRoute.admin.*`  | Admin route (`parentRefs`, `hostnames`, `rules`)  | `[]`    |

Cilium notes: `parentRefs[*].port` is ignored — target a Gateway listener via `sectionName`. Cross-namespace `backendRefs` require a `ReferenceGrant` in the backend namespace. The HTTPRoute and Ingress objects can coexist — migrate sub-routes one at a time.

### OpenBao integration

| Parameter                                  | Description                              | Default                                 |
| ------------------------------------------ | ---------------------------------------- | --------------------------------------- |
| `openbao.enabled`                          | Create `VaultAuth` and related resources | `false`                                 |
| `openbao.vaultConnectionRef`               | `VaultConnection` reference              | `vault-secrets-operator-system/default` |
| `openbao.vaultAuth.mount`                  | Kubernetes auth mount path               | `kubernetes`                            |
| `openbao.vaultAuth.role`                   | OpenBao role name                        | `infrastructure`                        |
| `openbao.vaultAuth.tokenExpirationSeconds` | Token TTL                                | `600`                                   |

### Admin setup job

| Parameter                                                  | Description                                    | Default                                     |
| ---------------------------------------------------------- | ---------------------------------------------- | ------------------------------------------- |
| `adminSetupJob.enabled`                                    | Run a one-shot job to create a permanent admin | `false`                                     |
| `adminSetupJob.keycloakUrl`                                | Override for the internal Keycloak URL         | `""`                                        |
| `adminSetupJob.deleteTemporaryAdmin`                       | Delete the bootstrap admin after promotion     | `true`                                      |
| `adminSetupJob.permanentAdmin.secretName`                  | Secret with permanent admin credentials        | `keycloak-admin-credentials`                |
| `adminSetupJob.permanentAdmin.usernameKey` / `passwordKey` | Keys in the secret                             | `permanent-username` / `permanent-password` |
| `adminSetupJob.ttlSecondsAfterFinished`                    | Auto-cleanup TTL                               | `300`                                       |

### Custom theme

| Parameter                        | Description                             | Default                         |
| -------------------------------- | --------------------------------------- | ------------------------------- |
| `customTheme.enabled`            | Mount a custom error theme ConfigMap    | `false`                         |
| `customTheme.errorRedirectUrl`   | URL to redirect to on auth errors       | `https://www.youtube.com`       |
| `customTheme.errorRedirectDelay` | Seconds before redirect (0 = immediate) | `0`                             |
| `customTheme.errorMessage`       | Inline error message                    | `Access denied. Redirecting...` |

### Realm import

| Parameter                                                 | Description                                               | Default         |
| --------------------------------------------------------- | --------------------------------------------------------- | --------------- |
| `realm.enabled`                                           | Render a `KeycloakRealmImport` CR                         | `false`         |
| `realm.name`                                              | Realm name                                                | `example`       |
| `realm.displayName`                                       | Realm display name                                        | `Example Realm` |
| `realm.browserFlow`                                       | Override browser flow (e.g. `browser-with-discord-check`) | `""`            |
| `realm.authenticationFlows` / `realm.authenticatorConfig` | Flow customisation lists                                  | `[]`            |

The chart does **not** auto-create OIDC clients — define them in the realm import YAML or via the Admin Console / API.

## Examples

### Minimal install with public ingress and existing DB secret

```yaml
operator:
  hostname:
    admin: "https://auth-admin.example.com"

keycloak:
  hostname: "https://auth.example.com"
  proxy:
    enabled: true
    mode: xforwarded

postgresql:
  clusterName: postgres-ha
  databaseNamespace: database
  database: keycloak
  username: keycloak
  existingSecret:
    name: keycloak-db-credentials
    usernameKey: username
    passwordKey: password

ingress:
  enabled: true
  public:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-production
    hosts:
      - host: auth.example.com
        paths:
          - { path: /realms, pathType: Prefix }
          - { path: /resources, pathType: Prefix }
          - { path: /js, pathType: Prefix }
    tls:
      - secretName: keycloak-public-tls
        hosts: [auth.example.com]
```

### HA install with HTTPRoute, OpenBao credentials, realm import, and admin promotion

```yaml
replicaCount: 3

keycloak:
  hostname: "https://auth.example.com"
  providers:
    - name: keycloak-discord
      url: https://github.com/wadahiro/keycloak-discord/releases/download/v0.6.1/keycloak-discord-0.6.1.jar

postgresql:
  useDynamicCredentials: true
  existingSecret:
    name: keycloak-db-dynamic
    usernameKey: username
    passwordKey: password

openbao:
  enabled: true
  vaultAuth:
    role: keycloak

httpRoute:
  enabled: true
  public:
    enabled: true
    parentRefs:
      - { name: cilium-gateway, namespace: gateway-system, sectionName: https }
    hostnames: [auth.example.com]
    rules:
      - matches:
          - path: { type: PathPrefix, value: /realms }
          - path: { type: PathPrefix, value: /resources }
          - path: { type: PathPrefix, value: /js }
        backendRefs: [{}]

adminSetupJob:
  enabled: true
  permanentAdmin:
    secretName: keycloak-admin-credentials
    usernameKey: permanent-username
    passwordKey: permanent-password

realm:
  enabled: true
  name: example
  displayName: Example Realm
```

## Persistence

The chart itself manages no PVCs. Database state lives in the referenced PostgreSQL cluster; the Keycloak operator handles ephemeral pod storage. Plan capacity at the database tier.

## Integration notes

- **Apps consume Keycloak as an OIDC provider.** Create an OIDC client in the realm — manually, via realm import (`realm.enabled`), or out-of-band via Terraform / `kcadm.sh`. This chart does **not** auto-create clients per relying party.
- **For apps without native OIDC**, deploy [oauth2-proxy](../oauth2-proxy) pointed at `${keycloak.hostname}/realms/<realm-name>` as the `oidcIssuerUrl`, then use `nginx.ingress.kubernetes.io/auth-url` (or your gateway's equivalent) on the upstream app's ingress.
- **Native OIDC** apps (e.g. Jellyfin SSO plugin, Grafana, ArgoCD) point directly at the same issuer URL — no oauth2-proxy needed.
- **Database** must be created in advance (or via [database-provisioner](../database-provisioner)). The chart references an existing `Cluster` by name; it does not create one.
- **Admin console** should be exposed only via the `admin` ingress/HTTPRoute on an internal hostname or VPN. Never expose `/admin` to the public internet.

## Upgrading

- **0.13.0**: Realm defaults changed — `realm.name` is now `example` and `realm.displayName` is now `Example Realm` (both were previously site-specific defaults). If you rely on the old defaults with `realm.enabled: true`, set `realm.name` (and `realm.displayName`) explicitly to keep your existing realm. Internal service FQDNs are now built from the new `clusterDomain` value (default `cluster.local`); override it if your cluster uses a non-default DNS domain.
- **0.12.x**: Hostname v2 only — `hostname-port` and `hostname-strict-https` have been removed. Migrate to `operator.hostname.strict` / `operator.hostname.admin`.
- When changing `keycloak.hostname` after install, restart the operator-managed pods so the new public URL propagates into issuer metadata.
- Provider JARs in `keycloak.providers` are re-downloaded on every pod restart — pin URLs to specific release versions.

## Support

- Upstream: <https://www.keycloak.org/> · <https://github.com/keycloak/keycloak>
- Operator: <https://www.keycloak.org/operator/installation>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

- Chart: Apache License 2.0
- Keycloak: [Apache License 2.0](https://github.com/keycloak/keycloak/blob/main/LICENSE.txt)

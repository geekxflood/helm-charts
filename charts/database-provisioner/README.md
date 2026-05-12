# Database Provisioner Helm Chart

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.0](https://img.shields.io/badge/AppVersion-1.0-informational?style=flat-square)

A Helm chart that deploys an automation `CronJob` for **per-application database provisioning** on top of a [CloudNativePG](https://cloudnative-pg.io/) `Cluster`. The CronJob watches for `databases.postgresql.cnpg.io` `Database` CRs across all namespaces and, for each unapplied one, creates the database, role, password, and optional cross-namespace application secret directly against the cluster's primary pod.

This is the glue that lets a normal application Helm chart say "give me a database" with a single CR — no human running `CREATE DATABASE` and copying credentials around.

## Features

- `CronJob` (`*/5 * * * *` by default) that reconciles all `Database` CRs cluster-wide
- Creates the role (`CREATE ROLE`), database (`CREATE DATABASE … OWNER …`), and grants `ALL PRIVILEGES` on `public` schema
- Generates a random password (`openssl rand -base64 32` by default) and stores it in `<cluster>-app-<owner>` `Secret` next to the primary
- Optional **cross-namespace secret materialisation** via annotations on the `Database` CR — drops a `username` / `password` / `database-url` `Secret` directly into the application's namespace
- Optional PostgreSQL **extensions** (`spec.extensions[].name`) installed per-database
- Marks `Database.status.applied: true` to make repeated runs idempotent
- Dry-run mode (`config.dryRun: true`) prints actions without executing them
- `ClusterRole` scoped to `databases.postgresql.cnpg.io`, `Cluster` pods, and `Secret` create — nothing else

## Prerequisites

- Kubernetes 1.24+
- Helm 3.0+
- [CloudNativePG operator](../postgres-ha/README.md) installed and the `databases.postgresql.cnpg.io` CRD present
- At least one CNPG `Cluster` running (e.g. from [postgres-ha](../postgres-ha))
- The CronJob's `ServiceAccount` requires permission to:
  - `list` / `get` / `patch` `databases.postgresql.cnpg.io` (cluster-wide)
  - `list` `pods` and `exec` into pods labelled `cnpg.io/cluster=<name>,role=primary`
  - `create` / `get` `secrets` in any namespace where you want the provisioner to write
  - The chart's `rbac.create: true` renders the required `ClusterRole` / `ClusterRoleBinding`

## Installation

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm install database-provisioner geekxflood/database-provisioner -n database --create-namespace
helm install database-provisioner geekxflood/database-provisioner -n database -f values.yaml
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `schedule` | Cron schedule for the reconcile loop | `*/5 * * * *` |
| `image.repository` | Container image (must include `kubectl`, `jq`, `openssl`) | `bitnami/kubectl` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `serviceAccount.create` | Create the ServiceAccount | `true` |
| `serviceAccount.name` | ServiceAccount name | `database-provisioner` |
| `rbac.create` | Create the `ClusterRole` / `ClusterRoleBinding` | `true` |
| `resources.requests` / `limits` | Pod resources | `50m`/`64Mi`, `100m`/`128Mi` |
| `config.logLevel` | `info` or `debug` | `info` |
| `config.dryRun` | Skip mutating operations | `false` |
| `config.passwordLength` | Length passed to `openssl rand -base64` | `32` |

## Database CR contract

The provisioner is driven entirely by `Database` CRs (`databases.postgresql.cnpg.io/v1`). Minimal CR:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: keycloak
  namespace: database          # must be the same namespace as the Cluster
spec:
  name: keycloak               # database name to create
  owner: keycloak              # role to create and assign ownership
  cluster:
    name: postgres-ha          # CNPG Cluster name in this namespace
  databaseReclaimPolicy: retain
  extensions:
    - name: pgcrypto
      ensure: present
```

### Cross-namespace credential delivery

To have the provisioner drop credentials into your app's namespace, annotate the `Database` CR:

| Annotation | Purpose |
|-----------|---------|
| `database-provisioner.cnpg.io/secret-namespace` | Target namespace for the application secret |
| `database-provisioner.cnpg.io/secret-name` | Name of the secret to create in that namespace |
| `database-provisioner.cnpg.io/connection-uri-scheme` | URI scheme for the `database-url` key (default `postgresql`) |

The resulting secret contains:

| Key | Value |
|-----|-------|
| `username` | The role (`spec.owner`) |
| `password` | The generated password |
| `database-url` | `<scheme>://<user>:<pass>@<cluster>-rw.<db-ns>.svc.gxf-cluster:5432/<dbname>` |

> Note: the connection host suffix `svc.gxf-cluster` is hard-coded in the provisioning script — adjust the script or your cluster DNS domain accordingly if you run a different cluster name.

## Examples

### Provision a database for Keycloak from the app's namespace

```yaml
# In the database namespace
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: keycloak
  namespace: database
  annotations:
    database-provisioner.cnpg.io/secret-namespace: identity
    database-provisioner.cnpg.io/secret-name: keycloak-db-credentials
spec:
  name: keycloak
  owner: keycloak
  cluster:
    name: postgres-ha
  extensions:
    - name: pgcrypto
      ensure: present
```

Within seconds (next CronJob tick), the `identity/keycloak-db-credentials` secret exists with `username`, `password`, and `database-url`. The Keycloak chart can then consume it via `postgresql.existingSecret`.

### Debug mode with frequent reconciliation

```yaml
schedule: "*/1 * * * *"
config:
  logLevel: debug
  dryRun: false
  passwordLength: 48
resources:
  limits:
    cpu: 200m
    memory: 256Mi
```

### Read-only safety check before going live

```yaml
config:
  dryRun: true
  logLevel: debug
```

The CronJob logs every action it *would* take but executes none — useful for verifying RBAC and CR contents before flipping `dryRun` back off.

## Persistence

None. State is held in:

- The cluster (Postgres roles, databases, extensions)
- The `Database.status.applied` field (idempotency marker)
- Kubernetes `Secret` resources (generated credentials)

The CronJob pods are ephemeral.

## Integration notes

- This chart **assumes** a CloudNativePG cluster exists and is reachable. It uses `kubectl exec` against the primary pod (selected by label `cnpg.io/cluster=<name>,role=primary`) — there is no direct database driver dependency.
- The provisioner does **not** delete databases when a `Database` CR is removed; reclaim is left to operators. Set `spec.databaseReclaimPolicy: delete` semantics out-of-band if you need teardown.
- The script is shell + `kubectl` + `jq` — keep that in mind if you swap the image to something more minimal.
- Combine with [postgres-ha](../postgres-ha) (the cluster) and a chart like [keycloak](../keycloak) (which references the resulting secret) for end-to-end automation.

## Upgrading

- The chart is stateless; upgrades replace the `CronJob` template. Existing `Database` CRs and secrets remain untouched.
- If the script changes between versions, completed `Database` CRs will not be re-run — clear `status.applied` if you intentionally want re-application.

## Support

- CloudNativePG `Database` CRD docs: <https://cloudnative-pg.io/documentation/current/declarative_database_management/>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

- Chart: Apache License 2.0
- CloudNativePG: [Apache License 2.0](https://github.com/cloudnative-pg/cloudnative-pg/blob/main/LICENSE)

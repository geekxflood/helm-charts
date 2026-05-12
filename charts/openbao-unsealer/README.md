# OpenBao Unsealer Helm Chart

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 2.3.1](https://img.shields.io/badge/AppVersion-2.3.1-informational?style=flat-square)

A Helm chart that deploys an automated unsealer for an [OpenBao](https://openbao.org/) cluster (the LF-stewarded fork of HashiCorp Vault). The chart renders a `CronJob` that periodically discovers OpenBao pods, checks their seal status via the HTTP API, and submits Shamir unseal keys read from a Kubernetes `Secret` until each node reports `sealed: false`.

This is intended for **homelab / self-hosted** clusters where automation matters more than the keys-in-cluster trade-off. Production deployments should prefer auto-unseal (KMS / cloud HSM) and treat this chart only as a bootstrapping aid.

## Features

- `CronJob` (default `*/5 * * * *`) that keeps OpenBao unsealed across pod restarts and node reboots
- Discovers OpenBao pod IPs via label selector `app.kubernetes.io/name=openbao`
- Submits unseal keys via the HTTP API (`POST /v1/sys/unseal`) — no `kubectl exec`, no `bao` binary required
- Idempotent: skips already-unsealed nodes and exits cleanly when the cluster is fully unsealed
- Configurable retry, retry delay, and overall timeout
- `concurrencyPolicy: Forbid` prevents overlapping runs
- Job TTL cleans up finished pods automatically
- Minimal RBAC: only `list pods` in the OpenBao namespace

> Security note: storing unseal keys in a Kubernetes `Secret` is convenient but defeats the security model of Shamir sealing. Use this only when the threat model allows it (single-tenant homelab) or migrate to OpenBao auto-unseal as soon as practical.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.0+
- An existing OpenBao cluster (initialised, with pods labelled `app.kubernetes.io/name=openbao`) running in the namespace named by `openbao.namespace`
- A Kubernetes `Secret` (default name `openbao-init-keys`) in the same namespace containing the Shamir unseal keys under keys `unseal-key-1` through `unseal-key-N`
- Network connectivity from the CronJob pod to the OpenBao pod IPs on the configured `openbao.port`

## Installation

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm install openbao-unsealer geekxflood/openbao-unsealer -n openbao
helm install openbao-unsealer geekxflood/openbao-unsealer -n openbao -f values.yaml
```

Create the keys secret first:

```bash
kubectl -n openbao create secret generic openbao-init-keys \
  --from-literal=unseal-key-1="<key1>" \
  --from-literal=unseal-key-2="<key2>" \
  --from-literal=unseal-key-3="<key3>" \
  --from-literal=unseal-key-4="<key4>" \
  --from-literal=unseal-key-5="<key5>"
```

## Configuration

### Target cluster

| Parameter             | Description                                              | Default   |
| --------------------- | -------------------------------------------------------- | --------- |
| `openbao.namespace`   | Namespace where OpenBao runs (must match the `Secret`)   | `openbao` |
| `openbao.serviceName` | OpenBao Service name (used only for `BAO_ADDR` env hint) | `openbao` |
| `openbao.port`        | HTTP API port                                            | `8200`    |
| `openbao.replicas`    | Expected replica count (informational, logged)           | `3`       |

### Unsealing parameters

| Parameter                     | Description                                              | Default |
| ----------------------------- | -------------------------------------------------------- | ------- |
| `unsealing.keysToUse`         | Number of keys to submit (≥ threshold)                   | `3`     |
| `unsealing.threshold`         | Shamir threshold (informational, must match init config) | `3`     |
| `unsealing.maxRetries`        | Retry count on API failure                               | `10`    |
| `unsealing.retryDelaySeconds` | Delay between retries                                    | `5`     |
| `unsealing.timeoutSeconds`    | Overall operation timeout                                | `300`   |

### Secret

| Parameter          | Description                                         | Default                         |
| ------------------ | --------------------------------------------------- | ------------------------------- |
| `secret.name`      | Name of the Kubernetes `Secret` holding unseal keys | `openbao-init-keys`             |
| `secret.namespace` | Namespace (must match `openbao.namespace`)          | `openbao`                       |
| `secret.keys`      | Ordered list of keys consumed by the script         | `unseal-key-1` … `unseal-key-5` |

### CronJob

| Parameter                            | Description               | Default       |
| ------------------------------------ | ------------------------- | ------------- |
| `cronjob.schedule`                   | Cron schedule             | `*/5 * * * *` |
| `cronjob.concurrencyPolicy`          | Concurrency policy        | `Forbid`      |
| `cronjob.successfulJobsHistoryLimit` | Successful jobs to retain | `3`           |
| `cronjob.failedJobsHistoryLimit`     | Failed jobs to retain     | `3`           |

### Job pod

| Parameter                        | Description                                              | Default                        |
| -------------------------------- | -------------------------------------------------------- | ------------------------------ |
| `job.image`                      | Image (must include `apk` to install `curl` + `kubectl`) | `alpine:latest`                |
| `job.imagePullPolicy`            | Pull policy                                              | `IfNotPresent`                 |
| `job.resources`                  | Pod resources                                            | `100m`/`128Mi`, `500m`/`512Mi` |
| `job.restartPolicy`              | Pod restart policy                                       | `OnFailure`                    |
| `job.backoffLimit`               | Job backoff limit                                        | `3`                            |
| `job.ttlSecondsAfterFinished`    | TTL for finished jobs                                    | `3600`                         |
| `serviceAccount.create` / `name` | ServiceAccount handling                                  | `true` / `openbao-unsealer`    |
| `rbac.create`                    | Create the `Role` / `RoleBinding` for `list pods`        | `true`                         |

## Examples

### Standard homelab install (3-replica OpenBao, 3-of-5 Shamir)

```yaml
openbao:
  namespace: openbao
  serviceName: openbao
  port: 8200
  replicas: 3

unsealing:
  keysToUse: 3
  threshold: 3
  maxRetries: 10
  retryDelaySeconds: 5

secret:
  name: openbao-init-keys
  namespace: openbao
  keys:
    - unseal-key-1
    - unseal-key-2
    - unseal-key-3
    - unseal-key-4
    - unseal-key-5

cronjob:
  schedule: "*/2 * * * *"
```

### Tighter loop with debugging on a single-node setup

```yaml
openbao:
  replicas: 1

unsealing:
  keysToUse: 1
  threshold: 1
  maxRetries: 30
  retryDelaySeconds: 2

cronjob:
  schedule: "*/1 * * * *"

job:
  image: alpine:3.19
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
```

## Persistence

None. The CronJob is stateless. Persistence lives in the OpenBao cluster's own storage.

## Integration notes

- **Trigger**: this chart does **not** unseal on a Kubernetes event (pod restart). It polls on a cron schedule — expect up to `cronjob.schedule` minutes of downtime after a restart unless you lower the interval.
- **Pod discovery** relies on the label `app.kubernetes.io/name=openbao`. If your OpenBao chart labels differ, adapt the ConfigMap template (`templates/configmap.yaml`).
- **No TLS** by default — the script uses `http://`. If your OpenBao API requires TLS, patch the script (`unseal_via_api`) and ensure the unsealer's CA cert is mounted into the pod.
- **Auto-unseal** (Transit, AWS KMS, GCP KMS, Azure Key Vault) is strongly preferred over this chart in production. Use this chart for getting started, single-tenant labs, or environments where the keys-in-cluster trade-off is acceptable.
- **Manual fallback**: `kubectl port-forward svc/openbao 8200:8200` and `bao operator unseal` — useful when debugging the chart itself.

## Upgrading

- The script changes (`templates/configmap.yaml`) are picked up on the next CronJob tick.
- Rotating unseal keys: update the `openbao-init-keys` secret, then trigger a one-shot run with `kubectl create job --from=cronjob/openbao-unsealer manual-unseal`.

## Support

- OpenBao: <https://openbao.org/> · <https://github.com/openbao/openbao>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

- Chart: Apache License 2.0
- OpenBao: [MPL-2.0](https://github.com/openbao/openbao/blob/main/LICENSE)

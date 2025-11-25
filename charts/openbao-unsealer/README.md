# OpenBao Unsealer

Automated unsealing for OpenBao cluster using unseal keys stored in Kubernetes secrets.

## Overview

This chart deploys a Kubernetes Job that automatically unseals the OpenBao cluster when it starts up. The unsealing process:

1. Reads unseal keys from a Kubernetes secret
2. Connects to each OpenBao pod
3. Submits unseal keys until the threshold is reached
4. Verifies all nodes are unsealed

## Prerequisites

- OpenBao cluster deployed with Shamir sealing
- Unseal keys stored in a Kubernetes secret named `openbao-init-keys`
- OpenBao pods accessible via `kubectl exec`

## Installation

```bash
helm install openbao-unsealer ./charts/openbao-unsealer \
  --namespace openbao \
  --values values.yaml
```

## Configuration

### Key Parameters

- `openbao.namespace`: Namespace where OpenBao is deployed (default: `openbao`)
- `openbao.serviceName`: Service name for OpenBao (default: `openbao`)
- `openbao.replicas`: Number of OpenBao replicas to unseal (default: `3`)
- `unsealing.keysToUse`: Number of unseal keys to use (default: `3`)
- `secret.name`: Name of the secret containing unseal keys (default: `openbao-init-keys`)

### Unseal Keys Secret

The secret must contain keys named `unseal-key-1` through `unseal-key-5`:

```bash
kubectl create secret generic openbao-init-keys \
  -n openbao \
  --from-literal=unseal-key-1="<key1>" \
  --from-literal=unseal-key-2="<key2>" \
  --from-literal=unseal-key-3="<key3>" \
  --from-literal=unseal-key-4="<key4>" \
  --from-literal=unseal-key-5="<key5>"
```

## How It Works

1. **Job Creation**: A Kubernetes Job is created that runs the unsealing script
2. **Key Loading**: The script reads unseal keys from the mounted secret
3. **Node Unsealing**: For each OpenBao pod:
   - Checks if already unsealed
   - Submits unseal keys via `kubectl exec`
   - Retries on failure with exponential backoff
4. **Verification**: Confirms all nodes are unsealed
5. **Cleanup**: Job completes and is cleaned up after TTL

## Monitoring

Check job status:

```bash
kubectl get jobs -n openbao
kubectl logs -n openbao -l app.kubernetes.io/name=openbao-unsealer
```

Check OpenBao status:

```bash
kubectl exec -n openbao openbao-0 -- bao status
```

## Troubleshooting

### Job fails to unseal

1. Verify unseal keys are correct:

   ```bash
   kubectl get secret openbao-init-keys -n openbao -o yaml
   ```

2. Check job logs:

   ```bash
   kubectl logs -n openbao -l app.kubernetes.io/name=openbao-unsealer
   ```

3. Verify OpenBao pods are running:

   ```bash
   kubectl get pods -n openbao
   ```

### Manual unsealing

If the job fails, manually unseal:

```bash
kubectl port-forward -n openbao svc/openbao 8200:8200 &
export BAO_ADDR='http://127.0.0.1:8200'
bao operator unseal <KEY1>
bao operator unseal <KEY2>
bao operator unseal <KEY3>
```

## Security Considerations

- Unseal keys are mounted as read-only secrets
- Job runs with minimal RBAC permissions
- Completed jobs are automatically cleaned up
- Keys are never logged or exposed

## References

- [OpenBao Documentation](https://openbao.org/)
- [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)

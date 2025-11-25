# Plex Helm Chart

This Helm chart deploys Plex Media Server on Kubernetes with support for NVIDIA GPU hardware transcoding.

## Features

- NVIDIA GPU support for hardware-accelerated transcoding
- GPU time-slicing support (multiple pods can share the same GPU)
- Persistent storage for media libraries and configuration
- Ingress configuration with TLS support
- Configurable resource requests and limits

## Prerequisites

- Kubernetes cluster with containerd runtime
- NVIDIA GPU Operator installed (for GPU support)
- GPU time-slicing configured (optional, for sharing GPU between multiple pods)
- RuntimeClass `nvidia` configured
- Persistent volumes for media storage
- Plex claim token (for initial server setup)

## Initial Setup

### 1. Generate Plex Claim Token

Before deploying, obtain a claim token from Plex:

1. Visit https://www.plex.tv/claim/
2. Sign in with your Plex account
3. Copy the claim token (valid for 4 minutes)
4. Add it to `values.yaml`:

```yaml
env:
  - name: PLEX_CLAIM
    value: claim-XXXXXXXXXXXXXXXXXXXX
```

### 2. Deploy Plex

```bash
helm install plex . --namespace media
```

**Note**: Initial deployment may take 5-10 minutes as the iSCSI volume needs to be formatted.

### 3. Complete Initial Server Setup

After deployment, you need to complete the initial Plex server configuration:

#### Option A: Automated API Setup (Recommended)

Use the provided setup script to automatically configure Plex via the REST API:

```bash
# Run the automated setup script
./plex-api-setup.sh
```

The script will:
1. Port-forward to the Plex service
2. Verify server connection and get server identity
3. Prompt for your Plex account token
4. Configure server preferences (name, GPU transcoding)
5. Create media libraries (TV Shows, Anime, Movies)
6. Trigger initial library scan

**Getting your Plex Token:**
1. Visit https://www.plex.tv/claim/
2. Open https://app.plex.tv/desktop/
3. Open browser DevTools (F12) → Application → Local Storage
4. Copy the value of `myPlexAccessToken`

#### Option B: Manual Web UI Setup

```bash
# Forward Plex port to localhost
kubectl port-forward -n media svc/plex 32400:32400

# Access Plex at http://localhost:32400/web
# Complete the server setup wizard manually
```

#### Option C: Custom API Integration

For custom automation, use the Plex REST API directly. See [Plex API Documentation](https://developer.plex.tv/pms/) for available endpoints:

**Key Endpoints:**
- `GET /identity` - Server identity and machine ID
- `PUT /:/prefs` - Configure server preferences
- `POST /library/sections` - Create media libraries
- `POST /library/sections/{id}/refresh` - Trigger library scan
- `GET /library/sections` - List all libraries

**Example:**
```bash
# Get server identity
curl http://localhost:32400/identity

# Set server name (requires X-Plex-Token)
curl -X PUT "http://localhost:32400/:/prefs?FriendlyName=MyServer" \
  -H "X-Plex-Token: YOUR_TOKEN"

# Create TV library
curl -X POST "http://localhost:32400/library/sections" \
  -H "X-Plex-Token: YOUR_TOKEN" \
  -d "name=TV%20Shows" \
  -d "type=show" \
  -d "location=/data/show" \
  -d "scanner=Plex%20Series%20Scanner" \
  -d "agent=tv.plex.agents.series"
```

After initial setup is complete, access Plex via the configured ingress URLs.

### 4. Access Methods

Once configured, Plex is accessible via:

- **Local Network**: https://plex.local.geekxflood.io (Cilium Ingress with TLS)
- **Tailscale Network**: https://plex.hen-morpho.ts.net (Tailscale Funnel enabled)

## GPU Configuration

### Enabling GPU Support

GPU support is controlled by the `gpu.enabled` flag in `values.yaml`. When enabled, the chart will:

1. Set the `runtimeClassName` to `nvidia` (or your custom value)
2. Add GPU resource requests and limits (`nvidia.com/gpu`)
3. Inject NVIDIA environment variables (`NVIDIA_VISIBLE_DEVICES`, `NVIDIA_DRIVER_CAPABILITIES`)
4. Schedule pods on nodes with GPU available

### GPU Configuration Options

```yaml
gpu:
  enabled: true               # Enable/disable GPU support
  runtimeClass: nvidia        # RuntimeClass for GPU access
  count: 1                    # Number of GPU slices to request (with time-slicing)
```

### GPU Time-Slicing

If your cluster has GPU time-slicing configured, you can share a single GPU between multiple pods. With time-slicing:

- `gpu.count: 1` requests one virtual GPU slice
- Multiple Plex instances (or other GPU workloads) can share the same physical GPU
- The GPU scheduler handles time-multiplexing between workloads

Refer to the `Optimisation.md` file in the repository root for GPU time-slicing setup details.

### Disabling GPU

To disable GPU support and run Plex without hardware transcoding:

```yaml
gpu:
  enabled: false
```

When GPU is disabled:

- No `runtimeClassName` is set
- No GPU resources are requested
- NVIDIA environment variables are not injected
- Pod can be scheduled on any node (without GPU)

## Resource Configuration

You can add additional CPU and memory resource requests/limits in the `resources` section:

```yaml
resources:
  limits:
    cpu: 4000m
    memory: 8Gi
  requests:
    cpu: 2000m
    memory: 4Gi
```

When GPU is enabled, the chart automatically merges these with GPU resource requests:

```yaml
# Automatically generated when gpu.enabled is true
resources:
  limits:
    nvidia.com/gpu: 1
    cpu: 4000m        # Your custom limit
    memory: 8Gi       # Your custom limit
  requests:
    nvidia.com/gpu: 1
    cpu: 2000m        # Your custom request
    memory: 4Gi       # Your custom request
```

## Node Selection

The chart includes node selectors and affinity rules to schedule Plex on nodes with NVIDIA GPUs:

```yaml
nodeSelector:
  nvidia.com/gpu.present: "true"

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: nvidia.com/gpu.present
              operator: In
              values:
                - "true"
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - worker-01
```

This ensures Plex pods are scheduled on GPU-enabled nodes and preferably on `worker-01`.

## Installation

### From the Chart Directory

```bash
cd media/charts/plex
helm install plex . --namespace media --create-namespace
```

### Upgrading

```bash
helm upgrade plex . --namespace media
```

### Uninstalling

```bash
helm uninstall plex --namespace media
```

## Verifying GPU Access

After deployment, verify GPU access inside the Plex pod:

```bash
# Get the pod name
kubectl get pods -n media -l app.kubernetes.io/name=plex

# Check NVIDIA GPU is visible
kubectl exec -n media -it <pod-name> -- nvidia-smi
```

You should see output showing the GPU(s) available to the container.

## Troubleshooting

### GPU Not Detected

1. Verify RuntimeClass exists:

   ```bash
   kubectl get runtimeclass nvidia
   ```

2. Check node labels:

   ```bash
   kubectl get nodes --show-labels | grep nvidia
   ```

3. Verify GPU Operator is running:

   ```bash
   kubectl get pods -n gpu-operator-resources
   ```

### Pod Stuck in Pending

Check events to see why the pod cannot be scheduled:

```bash
kubectl describe pod -n media <pod-name>
```

Common issues:

- No nodes with available GPU resources
- GPU already allocated to other pods (without time-slicing)
- RuntimeClass not found

### Transcoding Not Using GPU

1. Check Plex transcoder settings in the web UI
2. Verify `NVIDIA_VISIBLE_DEVICES` and `NVIDIA_DRIVER_CAPABILITIES` are set:

   ```bash
   kubectl exec -n media <pod-name> -- env | grep NVIDIA
   ```

3. Check Plex logs for transcoding activity:

   ```bash
   kubectl logs -n media <pod-name>
   ```

## Storage

The chart uses the following persistent volume claims:

- `plex-config-iscsi-pvc`: Plex configuration and metadata (200Gi)
- `show-pvc`: TV shows library
- `anime-pvc`: Anime library
- `movie-pvc`: Movies library
- `audiobooks-pvc`: Audiobooks library

Ensure these PVCs exist before deploying the chart.

## Ingress

The chart creates an Ingress resource for accessing Plex via HTTPS:

- URL: `https://plex.local.geekxflood.io`
- TLS certificate issued by cert-manager using Let's Encrypt
- Ingress controller: Traefik

## Environment Variables

Base environment variables configured in `values.yaml`:

- `PUID`: User ID for file permissions (default: 1000)
- `PGID`: Group ID for file permissions (default: 100)
- `TZ`: Timezone (default: Europe/Zurich)
- `VERSION`: Plex version to install (default: docker - latest)

GPU-specific environment variables (automatically added when `gpu.enabled: true`):

- `NVIDIA_VISIBLE_DEVICES`: Which GPUs to expose (default: all)
- `NVIDIA_DRIVER_CAPABILITIES`: NVIDIA driver capabilities to enable (default: all)

## References

- [Plex Docker Image Documentation](https://docs.linuxserver.io/images/docker-plex/)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/getting-started.html)
- [Kubernetes GPU Time-Slicing](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/gpu-sharing.html)

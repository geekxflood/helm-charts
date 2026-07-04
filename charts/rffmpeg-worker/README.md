# rffmpeg-worker Helm Chart

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 10.11.11](https://img.shields.io/badge/AppVersion-10.11.11-informational?style=flat-square)

Distributed Jellyfin transcode workers — [rffmpeg](https://github.com/joshuaboniface/rffmpeg) SSH receivers.

## Overview

The Jellyfin "brain" runs [rffmpeg](https://github.com/joshuaboniface/rffmpeg), which transparently replaces `ffmpeg`/`ffprobe` and dispatches every transcode job to a remote host over SSH. This chart deploys those remote hosts: minimal sshd pods built from [`ghcr.io/christopherime/rffmpeg-worker`](https://github.com/christopherime/rffmpeg-images) that carry the exact same `jellyfin-ffmpeg` as the brain's Jellyfin release.

Each entry in the `workers` list renders:

- **one single-replica Deployment** (strategy `Recreate`), pinned to a specific node via `nodeSelector: {kubernetes.io/hostname: <node>}`
- **one stable ClusterIP Service** named `<fullname>-<worker.name>` — the DNS name you hand to `rffmpeg add`

Node pinning is deliberate: one worker per node gives deterministic GPU-slice budgeting on heterogeneous GPUs (each physical card is time-sliced, and the cards differ per node). Do **not** replace the pinning with `topologySpreadConstraints`.

The image runs sshd as root. Its entrypoint installs `/ssh/authorized_keys` into `/root/.ssh`, generates SSH host keys, and symlinks `~/.nv` to `/nvcache` so the NVIDIA JIT cache stays off NFS.

## ⚠️ Version lockstep

**The worker image tag MUST equal the Jellyfin version running on the brain** (`image.tag: "10.11.11"` ⇔ brain Jellyfin 10.11.11). Jellyfin generates `jellyfin-ffmpeg` command lines for its own bundled ffmpeg build; argument sets drift between releases, so a mismatched worker fails or corrupts transcodes. Upgrade brain and workers in the same change.

## The identical-paths contract

rffmpeg passes **absolute paths** over SSH — whatever path Jellyfin sees, the worker must resolve to the same bytes. Volumes and mount paths are therefore rendered structurally by the chart (not raw passthrough) from the values below, and set them to your brain's real values (the defaults are neutral placeholders):

| Volume    | Source                              | Brain path               | Worker path              | Mode |
| --------- | ----------------------------------- | ------------------------ | ------------------------ | ---- |
| `config`  | PVC `config.claimName`   | `/config`                | `/config`                | RW   |
| `scratch` | scratch PVC subPath `<app>/subtitles`   | `/config/data/subtitles`   | `/config/data/subtitles`   | RW |
| `scratch` | scratch PVC subPath `<app>/attachments` | `/config/data/attachments` | `/config/data/attachments` | RW |
| `scratch` | scratch PVC subPath `<app>/transcodes`  | `/transcode`               | `/transcode`               | RW |
| `scratch` | scratch PVC subPath `<app>/temp`        | `/temp`                    | `/temp`                    | RW |
| media     | `mediaMounts[]` claims    | `/data/<library>`        | `/data/<library>`        | RO   |
| `ssh`     | Secret `rffmpeg-ssh` (key `authorized_keys`) | n/a (brain holds the private key) | `/ssh` | RO |
| `nvcache` | `emptyDir`                          | n/a                      | `/nvcache`               | RW   |

If the ArgoCD Application overrides any of these values, it must change the brain and every worker **together**.

## SSH key convention

The `rffmpeg-ssh` secret's `authorized_keys` entries should restrict the brain's key to the transcode wrapper only:

```text
command="/usr/local/bin/limited-wrapper.py",restrict ssh-ed25519 AAAA... rffmpeg@jellyfin
```

`restrict` disables port/agent/X11 forwarding and PTY allocation; the forced `command=` means the key can execute nothing but the ffmpeg wrapper, even though sshd runs as root.

## Bootstrapping workers on the brain

Workers are registered on the brain with `rffmpeg add`. Two rules:

1. **Register the stronger GPU FIRST.** rffmpeg breaks ties between idle hosts by insertion order, so the first-registered host soaks up jobs when everything is idle.
2. **Weight = concurrent-transcode capacity.** It is an rffmpeg-side setting applied at `rffmpeg add --weight N` time — it is *not* configured in this chart.

```bash
# From the brain pod (order matters — strongest first):
rffmpeg add --weight 4 rffmpeg-worker-worker-a.<ns>.svc.cluster.local  # 16G-class card
rffmpeg add --weight 2 rffmpeg-worker-worker-b.<ns>.svc.cluster.local  # 5G-class card
```

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- NVIDIA device plugin + `nvidia` RuntimeClass on the target nodes (when `gpu.enabled`)
- The brain's PVCs and the `rffmpeg-ssh` secret present in the release namespace

## Installation

```bash
helm install rffmpeg-worker charts/rffmpeg-worker
```

Default values render **no workers** — supply the `workers` list (and the volume claims) per environment; real values belong in your private deployment repo, not here.

## Configuration

### Image Parameters

| Parameter          | Description                                              | Default                                |
| ------------------ | -------------------------------------------------------- | -------------------------------------- |
| `image.repository` | Worker image repository                                  | `ghcr.io/christopherime/rffmpeg-worker` |
| `image.tag`        | Image tag — **must equal the brain's Jellyfin version**  | `"10.11.11"`                           |
| `image.pullPolicy` | Image pull policy                                        | `IfNotPresent`                         |
| `imagePullSecrets` | Image pull secrets                                       | `[]`                                   |

### Worker Parameters

| Parameter             | Description                                                        | Default          |
| --------------------- | ------------------------------------------------------------------ | ---------------- |
| `workers`             | List of workers; each renders one Deployment + one Service         | `[]` (none) |
| `workers[].name`      | DNS-safe suffix; resources are named `<fullname>-<name>`           | —                |
| `workers[].node`      | `kubernetes.io/hostname` value the worker is pinned to             | —                |
| `workers[].resources` | Optional per-worker override of the top-level `resources` default  | unset            |

### GPU Parameters

| Parameter          | Description                                                    | Default  |
| ------------------ | -------------------------------------------------------------- | -------- |
| `gpu.enabled`      | Enable GPU support (runtimeClass + nvidia.com/gpu resources)   | `true`   |
| `gpu.runtimeClass` | Runtime class for GPU (`spec.runtimeClassName`)                | `nvidia` |
| `gpu.count`        | GPUs per worker — added to **both** requests and limits        | `1`      |

### Service Parameters

| Parameter      | Description                          | Default     |
| -------------- | ------------------------------------ | ----------- |
| `service.type` | Service type (one Service per worker) | `ClusterIP` |
| `service.port` | SSH port                             | `22`        |

### Environment Variables

| Parameter | Description                                 | Default                     |
| --------- | ------------------------------------------- | --------------------------- |
| `env`     | Environment variables array                 | `[]`                        |
| `envFrom` | Environment variables from ConfigMap/Secret | `[]`                        |

### Probe Parameters

| Parameter        | Description                       | Default                        |
| ---------------- | --------------------------------- | ------------------------------ |
| `readinessProbe` | Readiness probe (sshd TCP socket) | `tcpSocket: ssh`, delay 3s     |
| `livenessProbe`  | Liveness probe (sshd TCP socket)  | `tcpSocket: ssh`, delay 10s    |

### Resource Management

| Parameter   | Description                                             | Default                                              |
| ----------- | ------------------------------------------------------- | ---------------------------------------------------- |
| `resources` | Default per-worker resources (worker entry can override) | requests `cpu: 500m` / `memory: 1Gi`, limits `memory: 4Gi` |

### Storage Contract Parameters

| Parameter               | Description                                             | Default                       |
| ----------------------- | ------------------------------------------------------- | ----------------------------- |
| `config.claimName`      | Jellyfin config PVC (shared with the brain)             | `jellyfin-config`             |
| `config.mountPath`      | Config mount path                                       | `/config`                     |
| `scratch.claimName`     | Shared scratch PVC                                      | `transcode-scratch`           |
| `scratch.mounts`        | subPath → mountPath pairs (must match the brain 1:1)    | See values.yaml               |
| `mediaMounts`           | Media library PVCs `{name, claimName, mountPath}` — always mounted read-only | 8 libraries at `/data/*` |
| `ssh.secretName`        | Secret with `authorized_keys` key                       | `rffmpeg-ssh`                 |
| `ssh.mountPath`         | Secret mount path                                       | `/ssh`                        |
| `nvcache.mountPath`     | NVIDIA JIT cache emptyDir mount path                    | `/nvcache`                    |
| `nvcache.sizeLimit`     | Optional emptyDir size limit                            | unset                         |

### Standard Parameters

| Parameter                    | Description                                                     | Default |
| ---------------------------- | --------------------------------------------------------------- | ------- |
| `nameOverride`               | Override chart name                                             | `""`    |
| `fullnameOverride`           | Override full chart name                                        | `""`    |
| `serviceAccount.create`      | Create service account                                          | `true`  |
| `serviceAccount.automount`   | Automount service account token                                 | `true`  |
| `serviceAccount.annotations` | Service account annotations                                     | `{}`    |
| `serviceAccount.name`        | Service account name                                            | `""`    |
| `podAnnotations`             | Pod annotations                                                 | `{}`    |
| `podLabels`                  | Pod labels                                                      | `{}`    |
| `podSecurityContext`         | Pod security context (image needs root sshd)                    | `{}`    |
| `securityContext`            | Container security context                                      | `{}`    |
| `nodeSelector`               | Global node selector — the per-worker `node` pin always wins    | `{}`    |
| `tolerations`                | Tolerations                                                     | `[]`    |
| `affinity`                   | Affinity rules                                                  | `{}`    |

## Examples

### Add a third worker with custom resources

```yaml
workers:
  - name: worker-a
    node: node-a.example.com
  - name: worker-b
    node: node-b.example.com
  - name: worker-c
    node: node-c.example.com
    resources:
      requests:
        cpu: 1
        memory: 2Gi
      limits:
        memory: 8Gi
```

Then register it on the brain (weight = concurrent-transcode capacity of that card):

```bash
rffmpeg add --weight 2 rffmpeg-worker-worker-c.<ns>.svc.cluster.local
```

### CPU-only workers

```yaml
gpu:
  enabled: false
```

## Uninstallation

```bash
helm uninstall rffmpeg-worker
```

Remember to `rffmpeg remove` the corresponding hosts on the brain.

## Support

For issues and questions:

- [rffmpeg Documentation](https://github.com/joshuaboniface/rffmpeg)
- [Worker image](https://github.com/christopherime/rffmpeg-images)
- [Chart Repository Issues](https://github.com/geekxflood/helm-charts/issues)

## License

This Helm chart is licensed under the Apache License 2.0.

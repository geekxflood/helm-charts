# MkDocs Material Helm Chart

![Version: 1.1.1](https://img.shields.io/badge/Version-1.1.1-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 9.7.6](https://img.shields.io/badge/AppVersion-9.7.6-informational?style=flat-square)

A Helm chart that deploys a [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) documentation site, with a `git-sync` sidecar that continuously pulls the documentation content from a Git repository. The result is a self-hosted wiki where editors push Markdown to Git and the site updates within seconds — no rebuild pipeline, no image rebuild.

The chart deploys the `squidfunk/mkdocs-material` container running `mkdocs serve` with live reload, alongside the `registry.k8s.io/git-sync/git-sync` sidecar. Content lives on a shared PVC.

## Features

- `git-sync` v4 sidecar with configurable repo, branch, depth, and sync period
- Public HTTPS, SSH (deploy key), or HTTPS-with-token authentication for private repositories
- Optional `subPath` for monorepos where docs live under e.g. `docs/`
- `liveReload` enabled by default — the running `mkdocs serve` instance picks up changes from `git-sync` automatically
- Persistent shared volume mounted by both containers (default `5Gi`, accessMode `ReadWriteOnce`)
- Standard `Ingress` or Gateway API `HTTPRoute` (Cilium / Istio / Envoy Gateway compatible)
- Liveness / readiness probes against `mkdocs serve`
- Optional MkDocs plugins installed via init container (Draw.io diagram support included as a toggle)
- Restricted security context (non-root, dropped caps, configurable seccomp via pod-level overrides)

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- A Git repository containing the MkDocs source tree (see structure below). **`gitSync.repo` must be set** — the chart has no useful default.
- A `StorageClass` supporting `ReadWriteOnce` (or supply `persistence.existingClaim`)
- For private SSH repos: a Kubernetes `Secret` with key `ssh` holding the private key
- For private HTTPS repos: a Kubernetes `Secret` with keys `username` and `password` (or token)
- For TLS via Ingress / Gateway: cert-manager (or pre-issued certs)
- For Gateway API: Gateway CRDs and a Gateway resource

### Expected repository layout

```
your-docs-repo/
├── mkdocs.yml         # MkDocs configuration (required)
├── docs/              # Markdown sources
│   ├── index.md       # Homepage (required)
│   └── ...
└── requirements.txt   # Optional extra plugins (not auto-installed by this chart)
```

Minimal `mkdocs.yml`:

```yaml
site_name: My Docs
theme:
  name: material
nav:
  - Home: index.md
```

## Installation

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm install docs geekxflood/mkdocs-material \
  --set gitSync.repo=https://github.com/yourorg/docs.git \
  --set gitSync.branch=main
helm install docs geekxflood/mkdocs-material -f values.yaml
```

### Private repository (SSH deploy key)

```bash
kubectl create secret generic docs-git-ssh \
  --from-file=ssh=$HOME/.ssh/id_ed25519

helm install docs geekxflood/mkdocs-material \
  --set gitSync.repo=git@github.com:yourorg/docs.git \
  --set gitSync.ssh.enabled=true \
  --set gitSync.ssh.secretName=docs-git-ssh
```

### Private repository (HTTPS + PAT)

```bash
kubectl create secret generic docs-git-https \
  --from-literal=username=docs-bot \
  --from-literal=password=<personal-access-token>

helm install docs geekxflood/mkdocs-material \
  --set gitSync.repo=https://github.com/yourorg/docs.git \
  --set gitSync.https.enabled=true \
  --set gitSync.https.secretName=docs-git-https
```

## Configuration

### MkDocs container

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Replica count | `1` |
| `image.repository` | MkDocs Material image | `squidfunk/mkdocs-material` |
| `image.tag` | Image tag | `9.7.6` |
| `image.pullPolicy` | Pull policy | `Always` |
| `mkdocs.devAddr` | Bind address for `mkdocs serve` | `0.0.0.0:8000` |
| `mkdocs.liveReload` | Enable live reload | `true` |
| `mkdocs.strict` | Fail build on warnings | `false` |
| `env` | Extra env vars | `[{name: TZ, value: UTC}]` |
| `resources.requests` / `limits` | Pod resources | `100m`/`128Mi`, `500m`/`512Mi` |

### git-sync sidecar

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gitSync.enabled` | Enable the sidecar | `true` |
| `gitSync.image.repository` / `tag` | git-sync image | `registry.k8s.io/git-sync/git-sync` / `v4.5.1` |
| `gitSync.repo` | Git URL (**required**) | `""` |
| `gitSync.branch` | Branch | `main` |
| `gitSync.depth` | Clone depth | `1` |
| `gitSync.period` | Sync interval | `60s` |
| `gitSync.subPath` | Subdirectory inside the repo (e.g. `wiki`) | `""` |
| `gitSync.ssh.enabled` | Use SSH auth | `false` |
| `gitSync.ssh.secretName` | Secret with key `ssh` | `""` |
| `gitSync.https.enabled` | Use HTTPS auth | `false` |
| `gitSync.https.secretName` | Secret with keys `username` / `password` | `""` |

### Plugins (init-container installation)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `plugins.drawio.enabled` | Install `mkdocs-drawio` | `false` |
| `plugins.drawio.version` | Plugin version | `1.11.2` |

> Other plugins are not installable from values. Either:
> - Bake them into a custom image and set `image.repository`/`tag`, or
> - Add another init-container in your own overlay.

### Service & exposure

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` / `port` | Service type and port | `ClusterIP` / `8000` |
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.className` | Ingress class | `nginx` |
| `ingress.annotations` / `hosts` / `tls` | Standard ingress wiring | see `values.yaml` |
| `httpRoute.enabled` | Enable Gateway API HTTPRoute | `false` |
| `httpRoute.parentRefs` / `hostnames` / `rules` | Standard HTTPRoute wiring | `[]` |

### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Use a PVC for the synced docs | `true` |
| `persistence.size` | PVC size | `5Gi` |
| `persistence.accessMode` | PVC access mode | `ReadWriteOnce` |
| `persistence.storageClass` | StorageClass | `""` (cluster default) |
| `persistence.existingClaim` | Reuse an existing PVC | `""` |

### Scheduling

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls | `{}` / `[]` / `{}` |
| `podSecurityContext` / `securityContext` | Non-root by default | see `values.yaml` |

## Examples

### Public repo, public ingress with TLS

```yaml
gitSync:
  repo: https://github.com/example/wiki.git
  branch: main
  period: 30s

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
  hosts:
    - host: wiki.example.com
      paths:
        - { path: /, pathType: Prefix }
  tls:
    - secretName: wiki-tls
      hosts: [wiki.example.com]

persistence:
  size: 2Gi
```

### Private monorepo via Gateway API + subPath

```yaml
gitSync:
  repo: git@github.com:example/platform.git
  branch: main
  subPath: docs            # docs live at <repo>/docs/
  period: 30s
  ssh:
    enabled: true
    secretName: docs-git-ssh

ingress:
  enabled: false

httpRoute:
  enabled: true
  parentRefs:
    - { name: cilium-gateway, namespace: gateway-system, sectionName: https }
  hostnames: [docs.internal.example.com]
  rules:
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs: [{}]

plugins:
  drawio:
    enabled: true
    version: "1.11.2"

resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: "1"
    memory: 1Gi
```

## Persistence

The PVC is shared between the `mkdocs` container (reads files served by `mkdocs serve`) and the `git-sync` sidecar (writes the latest checkout). Size for the cloned working tree plus headroom for `mkdocs serve`'s own scratch files — a few hundred MiB is usually enough. With `ReadWriteOnce`, scaling beyond `replicaCount: 1` requires `ReadWriteMany` (NFS, CephFS) or a separate PVC per replica (you would need to template that yourself).

## Integration notes

- **Editing workflow**: editors push to the configured branch. `git-sync` pulls at `gitSync.period` and `mkdocs serve` live-reloads. No CI/CD required.
- **Build-time mode**: this chart runs `mkdocs serve`, not `mkdocs build`. For air-gapped or static-hosted deployments, build the site in CI and serve it from nginx instead — this chart is the wrong tool for that.
- **Multiple wikis** are easily achieved via multiple Helm releases with different `gitSync.repo` and `ingress.hosts` / `httpRoute.hostnames`.
- **TLS termination** belongs at the ingress / Gateway. `mkdocs serve` itself is HTTP-only.
- **Plugins beyond Draw.io** require a custom image. The chart's `plugins` block is intentionally minimal.

## Troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| 404 / empty page on `/` | Missing `docs/index.md` or wrong `subPath` |
| `git-sync` CrashLoopBackOff | Auth — verify the secret keys match (`ssh` for SSH; `username`+`password` for HTTPS) |
| Live reload not updating | `gitSync.period` too long, or `mkdocs.liveReload: false` |
| Permission denied on PVC | StorageClass user/group mismatch — `podSecurityContext.fsGroup: 1000` is required for the default image |

Useful commands:

```bash
kubectl logs deploy/docs -c mkdocs
kubectl logs deploy/docs -c git-sync
kubectl exec deploy/docs -c git-sync -- ls -la /tmp/git
```

## Upgrading

- **1.1.x**: live reload + plugin init-containers landed. Existing PVCs are reused.
- Bumping the MkDocs Material image (`image.tag`) is generally safe — restart picks up the new image and re-renders from the synced source.
- Changing `gitSync.repo` mid-flight will leave stale content in the PVC; delete the PVC (and lose the cache) or `kubectl exec` and `rm -rf` the working tree.

## Support

- MkDocs Material: <https://squidfunk.github.io/mkdocs-material/>
- git-sync: <https://github.com/kubernetes/git-sync>
- Chart issues: <https://github.com/geekxflood/helm-charts/issues>

## License

- Chart: Apache License 2.0
- MkDocs Material: [MIT License](https://github.com/squidfunk/mkdocs-material/blob/master/LICENSE)
- git-sync: [Apache License 2.0](https://github.com/kubernetes/git-sync/blob/master/LICENSE)

# MkDocs Material Helm Chart

This Helm chart deploys [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) - a beautiful, responsive documentation site built with Material Design.

## Features

- **MkDocs Material** - Material Design theme for MkDocs
- **Git-sync sidecar** - Automatically syncs wiki content from a Git repository
- **Auto-reload** - Live reload on content changes (perfect with git-sync)
- **Cilium Ingress** - HTTPS ingress with Let's Encrypt TLS certificates
- **Kyverno integration** - Log collection via log-tailer sidecar
- **Persistent storage** - PVC for wiki content

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- cert-manager (for TLS certificates)
- Cilium ingress controller
- A Git repository containing your MkDocs content

## Wiki Content Repository Structure

Your Git repository should have the following structure:

```
your-wiki-repo/
├── mkdocs.yml              # MkDocs configuration
├── docs/                   # Documentation source files
│   ├── index.md           # Homepage
│   ├── getting-started.md
│   └── ...
└── requirements.txt        # Python dependencies (optional)
```

### Example mkdocs.yml

```yaml
site_name: My Documentation
site_url: https://wiki.example.com
site_description: Technical Documentation Wiki

theme:
  name: material
  palette:
    # Light mode
    - scheme: default
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    # Dark mode
    - scheme: slate
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.instant
    - navigation.tracking
    - navigation.sections
    - navigation.expand
    - navigation.top
    - search.suggest
    - search.highlight
    - content.code.copy

markdown_extensions:
  - pymdownx.highlight
  - pymdownx.superfences
  - pymdownx.tasklist:
      custom_checkbox: true
  - admonition
  - pymdownx.details
  - toc:
      permalink: true

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - Cluster:
      - Architecture: cluster/architecture.md
      - Deployment: cluster/deployment.md
  - Applications:
      - Media Stack: apps/media.md
      - AI/LLM: apps/ai.md
```

## Installation

### 1. Create Git Repository for Wiki Content

Create a new Git repository for your wiki content:

```bash
mkdir gxf-wiki
cd gxf-wiki

# Create basic structure
mkdir docs
cat > mkdocs.yml <<EOF
site_name: GXF Wiki
theme:
  name: material
nav:
  - Home: index.md
EOF

cat > docs/index.md <<EOF
# Welcome to GXF Wiki

This is the documentation and wiki for the GXF Kubernetes Cluster.
EOF

# Initialize git
git init
git add .
git commit -m "Initial wiki setup"
git remote add origin https://github.com/user/docs.git
git push -u origin main
```

### 2. Install the Chart

#### Option A: Public Git Repository (HTTPS)

```bash
helm install mkdocs-material ./charts/mkdocs-material \
  --namespace knowledge \
  --create-namespace \
  --set gitSync.repo=https://github.com/user/docs.git \
  --set gitSync.branch=main
```

#### Option B: Private Git Repository (SSH)

First, create a secret with your SSH private key:

```bash
kubectl create secret generic git-ssh-secret \
  --namespace knowledge \
  --from-file=ssh=$HOME/.ssh/id_rsa
```

Then install the chart:

```bash
helm install mkdocs-material ./charts/mkdocs-material \
  --namespace knowledge \
  --create-namespace \
  --set gitSync.repo=git@github.com:user/docs.git \
  --set gitSync.branch=main \
  --set gitSync.ssh.enabled=true \
  --set gitSync.ssh.secretName=git-ssh-secret
```

#### Option C: Private Repository (HTTPS with Token)

Create a secret with your Git credentials:

```bash
kubectl create secret generic git-https-secret \
  --namespace knowledge \
  --from-literal=username=your-username \
  --from-literal=password=your-token
```

Then install:

```bash
helm install mkdocs-material ./charts/mkdocs-material \
  --namespace knowledge \
  --create-namespace \
  --set gitSync.repo=https://github.com/user/docs.git \
  --set gitSync.branch=main \
  --set gitSync.https.enabled=true \
  --set gitSync.https.secretName=git-https-secret
```

### 3. Access Your Wiki

Once deployed, access your wiki at:

```
https://wiki.example.com
```

The TLS certificate will be automatically provisioned by cert-manager.

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gitSync.enabled` | Enable git-sync sidecar | `true` |
| `gitSync.repo` | Git repository URL | `""` (must be set) |
| `gitSync.branch` | Git branch to sync | `main` |
| `gitSync.period` | Sync interval | `60s` |
| `gitSync.ssh.enabled` | Use SSH for git clone | `false` |
| `gitSync.ssh.secretName` | Secret containing SSH key | `""` |
| `gitSync.https.enabled` | Use HTTPS with credentials | `false` |
| `gitSync.https.secretName` | Secret with git credentials | `""` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | PVC size | `5Gi` |
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.hosts[0].host` | Ingress hostname | `wiki.example.com` |

### Full Configuration

See [values.yaml](values.yaml) for all available configuration options.

## Updating Wiki Content

With git-sync enabled (default), simply push changes to your Git repository:

```bash
cd gxf-wiki
# Edit your markdown files
vim docs/new-page.md

# Update navigation in mkdocs.yml
vim mkdocs.yml

# Commit and push
git add .
git commit -m "Add new documentation page"
git push
```

The wiki will automatically update within 60 seconds (configurable via `gitSync.period`).

## Troubleshooting

### Check MkDocs Logs

```bash
kubectl logs -n knowledge -l app.kubernetes.io/name=mkdocs-material -c mkdocs
```

### Check Git-Sync Logs

```bash
kubectl logs -n knowledge -l app.kubernetes.io/name=mkdocs-material -c git-sync
```

### Test Git Repository Access

```bash
# Exec into the git-sync container
kubectl exec -n knowledge -it deployment/mkdocs-material -c git-sync -- sh

# Check git sync status
ls -la /docs/
```

### Common Issues

**Issue**: Wiki shows "File not found" or empty page

**Solution**: Ensure your Git repository has:
- `mkdocs.yml` in the root
- `docs/` directory with markdown files
- `docs/index.md` as the homepage

**Issue**: Git-sync fails to clone repository

**Solution**:
- For SSH: Ensure SSH key has access to the repository
- For HTTPS with token: Ensure token has `repo` scope
- Check git-sync logs for authentication errors

**Issue**: Changes not appearing on wiki

**Solution**:
- Check git-sync logs to confirm successful sync
- Verify `gitSync.period` setting (default 60s)
- Check that changes are pushed to the correct branch

## ArgoCD Deployment

To deploy via ArgoCD, create an Application manifest in the kube-deployment repository.

Configure ArgoCD Application manifest to manage this chart deployment.

## Advanced Configuration

### Custom MkDocs Plugins

If your wiki requires additional MkDocs plugins, you can:

1. Create a custom Docker image with required plugins:

```dockerfile
FROM squidfunk/mkdocs-material:9.5.47
RUN pip install mkdocs-git-revision-date-localized-plugin
```

2. Build and push to your registry:

```bash
docker build -t your-registry/mkdocs-material:custom .
docker push your-registry/mkdocs-material:custom
```

3. Update values.yaml:

```yaml
image:
  repository: your-registry/mkdocs-material
  tag: custom
```

### Multiple Wiki Instances

You can deploy multiple wiki instances by installing the chart with different release names:

```bash
# Technical documentation
helm install tech-docs ./charts/mkdocs-material \
  --namespace knowledge \
  --set gitSync.repo=https://github.com/user/tech-docs.git \
  --set ingress.hosts[0].host=docs.example.com

# Runbooks
helm install runbooks ./charts/mkdocs-material \
  --namespace knowledge \
  --set gitSync.repo=https://github.com/user/runbooks.git \
  --set ingress.hosts[0].host=runbooks.example.com
```

## Maintainers

- geekxflood

## License

This Helm chart is provided as-is under the MIT license.

MkDocs Material is licensed under the MIT license. See https://squidfunk.github.io/mkdocs-material/license/

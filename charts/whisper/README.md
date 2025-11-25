# Whisper ASR Helm Chart

OpenAI Whisper ASR (Automatic Speech Recognition) Webservice for generating subtitles from audio/video files. Perfect for integration with Bazarr for automated subtitle generation.

## Overview

This Helm chart deploys the [whisper-webservice](https://github.com/ahmetoner/whisper-webservice) which provides a REST API for speech recognition using OpenAI's Whisper model. It's specifically designed to work with Bazarr for automatic subtitle generation from your media library.

## Features

- **Multiple ASR Engines**: OpenAI Whisper, Faster Whisper, or WhisperX
- **Multiple Model Sizes**: From tiny to large-v3 (balance speed vs accuracy)
- **GPU Support**: Optional NVIDIA GPU acceleration
- **REST API**: Swagger documentation at `/docs`
- **Model Caching**: Persistent storage prevents re-downloading models
- **Bazarr Integration**: Drop-in whisper provider for subtitle generation

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PersistentVolume provisioner (for model cache)
- (Optional) NVIDIA GPU with device plugin for GPU acceleration

## Installation

### Quick Start (GXF Cluster)

```bash
helm install whisper ./charts/whisper \
  --namespace media \
  --create-namespace \
  --values charts/whisper/values-gxf.yaml
```

### Custom Installation

1. Copy and customize values:

```bash
cp charts/whisper/values.yaml charts/whisper/my-values.yaml
```

2. Edit configuration as needed (model size, GPU, etc.)

3. Install:

```bash
helm install whisper ./charts/whisper \
  --namespace media \
  --values charts/whisper/my-values.yaml
```

## Bazarr Integration

### Step 1: Verify Whisper is Running

```bash
kubectl get pods -n media -l app.kubernetes.io/name=whisper
kubectl get svc -n media whisper
```

### Step 2: Get the Service Endpoint

The Whisper service will be available at:

```
http://whisper.media.svc.cluster.local:9000
```

Or if Bazarr is in the same namespace:

```
http://whisper:9000
```

### Step 3: Configure Bazarr

1. Open Bazarr web UI
2. Go to **Settings** → **Subtitles**
3. Scroll to **Whisper Provider**
4. Configure:
   - **Enabled**: ✓
   - **Endpoint**: `http://whisper:9000` (or full service DNS)
   - **Timeout**: 3600 (for long movies/episodes)
   - **Response**: json
5. Click **Test** to verify connection
6. **Save** settings

### Step 4: Adjust Subtitle Settings

In Bazarr **Settings** → **Subtitles**:

- **Minimum Score**: Lower to ~50-60% to accept Whisper-generated subtitles
  - Whisper scores: ~67% for episodes, ~51% for movies
- **Languages**: Enable languages you want Whisper to generate

### Step 5: Trigger Subtitle Generation

- **Manual**: Select media → "Manual Search" → Choose Whisper provider
- **Automatic**: Bazarr will use Whisper when no subtitles are found online

## Model Selection Guide

Choose based on your needs:

| Model | Speed | Accuracy | RAM | Use Case |
|-------|-------|----------|-----|----------|
| `tiny` | Fastest | Lowest | ~1GB | Quick testing |
| `base` | Fast | Good | ~1.5GB | **Recommended for most users** |
| `small` | Medium | Better | ~2.5GB | Better quality |
| `medium` | Slow | High | ~5GB | High quality |
| `large-v3` | Slowest | Best | ~10GB | Maximum accuracy |

**Recommendation**: Start with `base` model (default in values-gxf.yaml)

## ASR Engine Comparison

| Engine | Speed | RAM Usage | Accuracy |
|--------|-------|-----------|----------|
| `faster_whisper` | **4x faster** | Lower | Same as OpenAI |
| `openai_whisper` | Baseline | Baseline | Baseline |
| `whisperx` | Fast | Higher | Enhanced with alignment |

**Recommendation**: Use `faster_whisper` (default in values-gxf.yaml)

## GPU Acceleration

If you have NVIDIA GPUs in your cluster:

### Enable GPU in values-gxf.yaml:

```yaml
image:
  tag: "latest-gpu"

whisper:
  asrDevice: "cuda"

gpu:
  enabled: true
  count: 1
```

### Add Node Selector (if GPUs are on specific nodes):

```yaml
nodeSelector:
  nvidia.com/gpu: "true"
```

GPU acceleration can provide 2-5x speedup for transcription.

## Configuration

### Common Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `whisper.asrEngine` | ASR engine (faster_whisper, openai_whisper, whisperx) | `faster_whisper` |
| `whisper.asrModel` | Model size (tiny, base, small, medium, large-v3) | `base` |
| `whisper.asrDevice` | Device (cpu, cuda) | `cpu` |
| `whisper.modelIdleTimeout` | Seconds before unloading model | `300` |
| `gpu.enabled` | Enable GPU acceleration | `false` |
| `persistence.enabled` | Enable model cache persistence | `true` |
| `persistence.size` | Cache volume size | `10Gi` |
| `resources.limits.memory` | Memory limit | (varies by model) |

### Resource Requirements by Model

**CPU Mode:**

```yaml
# Tiny/Base
resources:
  limits:
    memory: 2Gi
  requests:
    memory: 1Gi

# Small
resources:
  limits:
    memory: 4Gi
  requests:
    memory: 2Gi

# Medium
resources:
  limits:
    memory: 8Gi
  requests:
    memory: 4Gi

# Large
resources:
  limits:
    memory: 16Gi
  requests:
    memory: 8Gi
```

## API Usage

### Swagger Documentation

Access API docs at: `http://whisper:9000/docs`

### Example: Transcribe Audio

```bash
# Port forward for testing
kubectl port-forward -n media svc/whisper 9000:9000

# Send audio file
curl -X POST "http://localhost:9000/asr?task=transcribe&language=en&output=json" \
  -H "accept: application/json" \
  -H "Content-Type: multipart/form-data" \
  -F "audio_file=@/path/to/audio.mp3"
```

### Supported Output Formats

- `json` - JSON with timestamps
- `text` - Plain text
- `srt` - SubRip subtitle format
- `vtt` - WebVTT subtitle format
- `tsv` - Tab-separated values

## Troubleshooting

### Pod Not Starting

Check pod logs:

```bash
kubectl logs -n media -l app.kubernetes.io/name=whisper
```

Common issues:
- **Out of memory**: Increase `resources.limits.memory` or use smaller model
- **GPU not found**: Verify NVIDIA device plugin is installed
- **Model download timeout**: Check internet connectivity from pod

### Bazarr Connection Failed

1. Verify Whisper service is running:

```bash
kubectl get svc -n media whisper
```

2. Test from Bazarr pod:

```bash
# Get Bazarr pod name
kubectl get pods -n media -l app.kubernetes.io/name=bazarr

# Test connection
kubectl exec -n media <bazarr-pod> -- curl -v http://whisper:9000
```

3. Check endpoint in Bazarr:
   - Must start with `http://`
   - Use service name if in same namespace: `http://whisper:9000`
   - Use full DNS if different namespace: `http://whisper.media.svc.cluster.local:9000`

### Slow Transcription

1. **Use faster_whisper engine** (4x faster):

```yaml
whisper:
  asrEngine: "faster_whisper"
```

2. **Use smaller model**:

```yaml
whisper:
  asrModel: "tiny"  # or "base"
```

3. **Enable GPU** (if available):

```yaml
image:
  tag: "latest-gpu"
whisper:
  asrDevice: "cuda"
gpu:
  enabled: true
```

### Model Downloads Taking Too Long

The first run downloads models (~140MB for base). Subsequent runs use cached models.

Check cache volume:

```bash
kubectl get pvc -n media whisper-cache
```

## Performance Benchmarks

Approximate transcription times for 1 hour of audio:

| Model | Engine | Device | Time |
|-------|--------|--------|------|
| base | faster_whisper | CPU (4 cores) | ~15 min |
| base | openai_whisper | CPU (4 cores) | ~60 min |
| base | faster_whisper | GPU (RTX 3080) | ~3 min |
| medium | faster_whisper | GPU (RTX 3080) | ~8 min |

## GXF Cluster Configuration

The `values-gxf.yaml` file is pre-configured with:

- **Engine**: `faster_whisper` (4x faster)
- **Model**: `base` (good balance)
- **Device**: `cpu` (change to `cuda` if GPU available)
- **Cache**: 5Gi persistent volume
- **Resources**: 4Gi memory limit, 2Gi request

## Upgrading

```bash
helm upgrade whisper ./charts/whisper \
  --namespace media \
  --values charts/whisper/values-gxf.yaml
```

## Uninstallation

```bash
# Remove deployment
helm uninstall whisper --namespace media

# Optionally remove cache PVC
kubectl delete pvc -n media whisper-cache
```

## Integration with Other Services

### Jellyfin/Plex/Emby

Use [SubGen](https://github.com/McCloudS/subgen) which can integrate with this Whisper service.

### Tautulli

Configure webhook to trigger subtitle generation via Whisper API.

## Additional Resources

- [Whisper ASR Webservice Docs](https://ahmetoner.com/whisper-webservice/)
- [Bazarr Whisper Provider Setup](https://wiki.bazarr.media/Additional-Configuration/Whisper-Provider/)
- [OpenAI Whisper GitHub](https://github.com/openai/whisper)
- [Faster Whisper](https://github.com/guillaumekln/faster-whisper)

## License

This Helm chart is provided as-is. The whisper-webservice is licensed under MIT.

## Support

For chart issues, open an issue in the repository.
For whisper-webservice issues, see the [upstream project](https://github.com/ahmetoner/whisper-webservice).

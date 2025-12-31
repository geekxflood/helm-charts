#!/bin/bash
set -e

# Define the root README path
README_FILE="README.md"

# Start generating the README content
cat <<EOF > "$README_FILE"
# Helm Charts

A collection of Helm charts for various applications, focused on media management, home automation, and utilities.

## Usage

To use these charts, clone this repository or add it as a local Helm repository.

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
```

## Available Charts

| Chart | Version | App Version | Description |
|---|---|---|---|

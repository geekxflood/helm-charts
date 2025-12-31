#!/bin/bash
set -e

# Define the root README path
README_FILE="README.md"

# Start generating the README content
# Note: We use 'EOF' quoted to prevent variable expansion inside the heredoc for the usage section
cat <<'EOF' > "$README_FILE"
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
EOF

# Iterate through charts and add them to the table
for dir in charts/*/; do
  if [ -f "${dir}Chart.yaml" ]; then
    NAME=$(grep "^name:" "${dir}Chart.yaml" | awk '{print $2}' | tr -d '"')
    VERSION=$(grep "^version:" "${dir}Chart.yaml" | awk '{print $2}' | tr -d '"')
    APP_VERSION=$(grep "^appVersion:" "${dir}Chart.yaml" | cut -d: -f2- | sed 's/^ *//' | tr -d '"')
    DESC=$(grep "^description:" "${dir}Chart.yaml" | cut -d: -f2- | sed 's/^ *//' | tr -d '"')
    
    # Get the directory name
    chart_dir=$(basename "$dir")
    
    # Append row to README
    echo "| [$NAME](charts/$chart_dir) | $VERSION | $APP_VERSION | $DESC |" >> "$README_FILE"
  fi
done

echo "" >> "$README_FILE"
echo "## Contributing" >> "$README_FILE"
echo "" >> "$README_FILE"
echo "Contributions are welcome! Please open an issue or submit a pull request." >> "$README_FILE"

# Check if README.md has changed
if git diff --name-only | grep -q "^README.md$"; then
    echo "README.md has been updated."
    git add "$README_FILE"
fi
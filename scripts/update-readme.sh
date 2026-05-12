#!/usr/bin/env bash
#
# Update the chart table inside the root README between the markers:
#   <!-- charts:start -->
#   <!-- charts:end -->
#
# Everything outside the markers is hand-maintained and preserved.
# The richer, browsable view of all charts lives at:
#   https://geekxflood.github.io/helm-charts/

set -euo pipefail

README_FILE="README.md"
START_MARKER="<!-- charts:start -->"
END_MARKER="<!-- charts:end -->"

if [ ! -f "$README_FILE" ]; then
  echo "Error: $README_FILE not found" >&2
  exit 1
fi

if ! grep -qF "$START_MARKER" "$README_FILE" || ! grep -qF "$END_MARKER" "$README_FILE"; then
  echo "Error: markers '$START_MARKER' / '$END_MARKER' missing from $README_FILE" >&2
  echo "Bail out instead of risking overwriting hand-maintained content." >&2
  exit 1
fi

# Build the new table content in a tmpfile.
TMP_TABLE=$(mktemp)
trap 'rm -f "$TMP_TABLE" "$TMP_README"' EXIT
TMP_README=$(mktemp)

{
  echo ""
  echo "| Chart | Version | App Version | Description |"
  echo "|---|---|---|---|"
  for dir in charts/*/; do
    [ -f "${dir}Chart.yaml" ] || continue
    name=$(awk -F': *' '/^name:/ {print $2; exit}' "${dir}Chart.yaml" | tr -d '"')
    version=$(awk -F': *' '/^version:/ {print $2; exit}' "${dir}Chart.yaml" | tr -d '"')
    app_version=$(awk -F': *' '/^appVersion:/ {print $2; exit}' "${dir}Chart.yaml" | tr -d '"')
    desc=$(awk -F': *' '/^description:/ {print $2; exit}' "${dir}Chart.yaml" | tr -d '"')
    chart_dir=$(basename "$dir")
    echo "| [${name}](charts/${chart_dir}) | ${version} | ${app_version} | ${desc} |"
  done
  echo ""
} > "$TMP_TABLE"

# Splice the table between the markers, preserving the rest of the file.
awk -v start="$START_MARKER" -v end="$END_MARKER" -v table_file="$TMP_TABLE" '
  $0 ~ start {
    print
    while ((getline line < table_file) > 0) print line
    close(table_file)
    inside = 1
    next
  }
  $0 ~ end {
    inside = 0
    print
    next
  }
  !inside { print }
' "$README_FILE" > "$TMP_README"

mv "$TMP_README" "$README_FILE"
# Clear trap target now that the tmp file has been moved.
TMP_README=""

if git diff --quiet -- "$README_FILE"; then
  echo "README.md is already up to date."
else
  echo "README.md chart table updated."
fi

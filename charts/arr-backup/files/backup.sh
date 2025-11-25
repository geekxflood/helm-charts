#!/bin/sh
# shellcheck shell=ash
set -e

BACKUP_DIR="/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ERRORS=0

echo "=== Starting backup process at $(date) ==="
echo "Backup directory: ${BACKUP_DIR}"

# Function to trigger backup for a service
backup_service() {
  local SERVICE_NAME="$1"
  local SERVICE_URL="$2"
  local API_KEY="$3"
  local ENABLED="$4"

  if [ "${ENABLED}" != "true" ]; then
    echo "⊘ ${SERVICE_NAME}: Skipped (disabled)"
    return 0
  fi

  if [ -z "${API_KEY}" ]; then
    echo "✗ ${SERVICE_NAME}: Skipped (no API key provided)"
    return 1
  fi

  echo "→ ${SERVICE_NAME}: Triggering backup command..."

  # Trigger backup via command API
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${SERVICE_URL}/api/command" \
    -H "X-Api-Key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"name":"Backup"}')

  HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
  BODY=$(echo "${RESPONSE}" | sed '$d')

  if [ "${HTTP_CODE}" = "200" ] || [ "${HTTP_CODE}" = "201" ]; then
    echo "✓ ${SERVICE_NAME}: Backup command submitted successfully"

    # Extract command ID from response
    COMMAND_ID=$(echo "${BODY}" | grep -o '"id":[0-9]*' | head -n1 | grep -o '[0-9]*')

    if [ -n "${COMMAND_ID}" ]; then
      echo "→ ${SERVICE_NAME}: Monitoring command ${COMMAND_ID}..."

      # Poll command status (max 60 seconds)
      WAIT_COUNT=0
      while [ ${WAIT_COUNT} -lt 12 ]; do
        sleep 5
        WAIT_COUNT=$((WAIT_COUNT + 1))

        CMD_STATUS=$(curl -s -X GET \
          "${SERVICE_URL}/api/command/${COMMAND_ID}" \
          -H "X-Api-Key: ${API_KEY}")

        STATUS=$(echo "${CMD_STATUS}" | grep -o '"status":"[^"]*"' | head -n1 | cut -d'"' -f4)

        if [ "${STATUS}" = "completed" ]; then
          echo "✓ ${SERVICE_NAME}: Backup command completed"
          break
        elif [ "${STATUS}" = "failed" ]; then
          echo "✗ ${SERVICE_NAME}: Backup command failed"
          ERRORS=$((ERRORS + 1))
          return 1
        fi
      done

      if [ ${WAIT_COUNT} -ge 12 ]; then
        echo "⚠ ${SERVICE_NAME}: Backup command timeout (still running)"
      fi
    fi

    # Download the latest backup
    echo "→ ${SERVICE_NAME}: Downloading backup..."

    # Get list of backups
    BACKUPS=$(curl -s -X GET \
      "${SERVICE_URL}/api/v3/system/backup" \
      -H "X-Api-Key: ${API_KEY}")

    # Extract the latest backup ID and name
    LATEST_BACKUP_ID=$(echo "${BACKUPS}" | grep -o '"id":[0-9]*' | head -n1 | grep -o '[0-9]*')
    LATEST_BACKUP_NAME=$(echo "${BACKUPS}" | grep -o '"name":"[^"]*"' | head -n1 | cut -d'"' -f4)

    if [ -n "${LATEST_BACKUP_ID}" ]; then
      # Construct filename
      if [ -n "${LATEST_BACKUP_NAME}" ]; then
        BACKUP_FILE="${BACKUP_DIR}/${SERVICE_NAME}_${TIMESTAMP}_${LATEST_BACKUP_NAME}"
      else
        BACKUP_FILE="${BACKUP_DIR}/${SERVICE_NAME}_${TIMESTAMP}_backup_${LATEST_BACKUP_ID}.zip"
      fi

      # Download the backup file
      curl -s -X GET \
        "${SERVICE_URL}/api/v3/system/backup/${LATEST_BACKUP_ID}" \
        -H "X-Api-Key: ${API_KEY}" \
        -H "Accept: application/octet-stream" \
        -o "${BACKUP_FILE}"

      if [ -f "${BACKUP_FILE}" ]; then
        FILESIZE=$(stat -c%s "${BACKUP_FILE}" 2>/dev/null || stat -f%z "${BACKUP_FILE}" 2>/dev/null || echo "0")
        if [ "${FILESIZE}" -gt 1024 ]; then
          FILESIZE_HUMAN=$(numfmt --to=iec "${FILESIZE}" 2>/dev/null || echo "${FILESIZE} bytes")
          echo "✓ ${SERVICE_NAME}: Backup downloaded (${FILESIZE_HUMAN})"
        else
          echo "✗ ${SERVICE_NAME}: Backup file seems too small (${FILESIZE} bytes), might be invalid"
          rm -f "${BACKUP_FILE}"
          ERRORS=$((ERRORS + 1))
        fi
      else
        echo "✗ ${SERVICE_NAME}: Failed to download backup file"
        ERRORS=$((ERRORS + 1))
      fi
    else
      echo "⚠ ${SERVICE_NAME}: Could not determine latest backup ID"
      ERRORS=$((ERRORS + 1))
    fi
  else
    echo "✗ ${SERVICE_NAME}: Backup command failed (HTTP ${HTTP_CODE})"
    echo "Response: ${BODY}"
    ERRORS=$((ERRORS + 1))
  fi
}

# Backup each service based on environment variables
if [ "${RADARR_ENABLED}" = "true" ]; then
  backup_service "Radarr" "${RADARR_URL}" "${RADARR_API_KEY}" "true"
fi

if [ "${SONARR_ENABLED}" = "true" ]; then
  backup_service "Sonarr" "${SONARR_URL}" "${SONARR_API_KEY}" "true"
fi

if [ "${PROWLARR_ENABLED}" = "true" ]; then
  backup_service "Prowlarr" "${PROWLARR_URL}" "${PROWLARR_API_KEY}" "true"
fi

if [ "${BAZARR_ENABLED}" = "true" ]; then
  backup_service "Bazarr" "${BAZARR_URL}" "${BAZARR_API_KEY}" "true"
fi

# Cleanup old backups if retention is enabled
if [ "${RETENTION_ENABLED}" = "true" ] && [ "${RETENTION_DAYS}" -gt 0 ]; then
  echo ""
  echo "→ Cleaning up backups older than ${RETENTION_DAYS} days..."
  DELETED=$(find "${BACKUP_DIR}" -name "*.zip" -type f -mtime +"${RETENTION_DAYS}" -delete -print | wc -l)
  echo "✓ Cleaned up ${DELETED} old backup(s)"
fi

echo ""
echo "=== Backup process completed at $(date) ==="
echo "Total errors: ${ERRORS}"

# List current backups
echo ""
echo "Current backups:"
ls -lh "${BACKUP_DIR}"/*.zip 2>/dev/null || echo "No backups found"

if [ ${ERRORS} -gt 0 ]; then
  echo ""
  echo "⚠ Backup completed with ${ERRORS} error(s)"
  exit 1
fi

exit 0

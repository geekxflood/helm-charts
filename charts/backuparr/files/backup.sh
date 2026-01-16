#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Backuparr - Automated backup for media applications
# Supports: Servarr apps, Jellyfin, Sabnzbd, Overseerr, and more
# ============================================================

BACKUP_DIR="${BACKUP_DIR:-/backup}"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ERRORS=0
SUCCESS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $(date '+%H:%M:%S') $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $(date '+%H:%M:%S') $1"; SUCCESS=$((SUCCESS + 1)); }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $(date '+%H:%M:%S') $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"; ERRORS=$((ERRORS + 1)); }
log_skip()  { echo -e "${CYAN}[SKIP]${NC}  $(date '+%H:%M:%S') $1"; }

# ============================================================
# Helper: Make API request
# ============================================================
api_request() {
    local method="$1"
    local url="$2"
    local api_key="$3"
    local data="${4:-}"

    local args=(-sf -X "$method" -H "X-Api-Key: ${api_key}" -H "Content-Type: application/json")
    [[ -n "$data" ]] && args+=(-d "$data")

    curl "${args[@]}" "$url" 2>/dev/null
}

# ============================================================
# Servarr API backup (Radarr, Sonarr, Prowlarr, Lidarr, Readarr)
# Note: Servarr apps don't expose backup download via API.
# Backups are created and stored in each app's config directory.
# ============================================================
backup_servarr() {
    local app_name="$1"
    local app_url="$2"
    local api_key="$3"
    local api_version="${4:-v3}"

    if [[ -z "$api_key" ]]; then
        log_skip "$app_name - No API key"
        return 0
    fi

    log_info "$app_name - Starting Servarr API backup..."

    # Trigger backup
    log_info "$app_name - Triggering backup..."
    local response
    response=$(api_request POST "${app_url}/api/${api_version}/command" "$api_key" '{"name":"Backup"}') || {
        log_error "$app_name - Failed to trigger backup"
        return 1
    }

    local command_id
    command_id=$(echo "$response" | jq -r '.id // empty')

    # Wait for completion
    if [[ -n "$command_id" ]]; then
        log_info "$app_name - Waiting for completion..."
        for _ in {1..24}; do
            sleep 5
            local status
            status=$(api_request GET "${app_url}/api/${api_version}/command/${command_id}" "$api_key" | jq -r '.status // "unknown"')
            [[ "$status" == "completed" ]] && break
            [[ "$status" == "failed" ]] && { log_error "$app_name - Backup failed"; return 1; }
        done
    fi

    # Verify backup was created
    local backups backup_name backup_size
    backups=$(api_request GET "${app_url}/api/${api_version}/system/backup" "$api_key") || {
        log_error "$app_name - Failed to list backups"
        return 1
    }

    backup_name=$(echo "$backups" | jq -r '.[0].name // empty')
    backup_size=$(echo "$backups" | jq -r '.[0].size // 0')

    [[ -z "$backup_name" ]] && { log_error "$app_name - No backups found"; return 1; }

    # Convert size to KB
    local size_kb=$((backup_size / 1024))
    log_ok "$app_name - Backup created: ${backup_name} (${size_kb} KB) - stored in app config"
}

# ============================================================
# Sabnzbd backup via API
# ============================================================
backup_sabnzbd() {
    local app_url="$1"
    local api_key="$2"

    if [[ -z "$api_key" ]]; then
        log_skip "sabnzbd - No API key"
        return 0
    fi

    log_info "sabnzbd - Starting backup..."

    local app_backup_dir="${BACKUP_DIR}/sabnzbd/${DATE}"
    mkdir -p "$app_backup_dir"

    # Get config via API
    local backup_file="${app_backup_dir}/sabnzbd_${TIMESTAMP}.ini"
    curl -sf "${app_url}/api?mode=get_config&output=text&apikey=${api_key}" -o "$backup_file" || {
        log_error "sabnzbd - Failed to get config"
        return 1
    }

    local size=$(($(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file") / 1024))
    [[ $size -lt 1 ]] && { rm -f "$backup_file"; log_error "sabnzbd - Backup too small"; return 1; }

    log_ok "sabnzbd - Saved (${size} KB)"
}

# ============================================================
# Overseerr/Jellyseerr backup via API
# ============================================================
backup_overseerr() {
    local app_name="$1"
    local app_url="$2"
    local api_key="$3"

    if [[ -z "$api_key" ]]; then
        log_skip "$app_name - No API key"
        return 0
    fi

    log_info "$app_name - Starting backup..."

    local app_backup_dir="${BACKUP_DIR}/${app_name}/${DATE}"
    mkdir -p "$app_backup_dir"

    # Trigger cache flush first
    curl -sf -X POST "${app_url}/api/v1/settings/cache/flush" \
        -H "X-Api-Key: ${api_key}" >/dev/null 2>&1 || true

    # Get settings export
    local backup_file="${app_backup_dir}/${app_name}_${TIMESTAMP}.json"
    curl -sf "${app_url}/api/v1/settings/main" \
        -H "X-Api-Key: ${api_key}" -o "$backup_file" || {
        log_error "$app_name - Failed to export settings"
        return 1
    }

    local size=$(($(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file") / 1024))
    [[ $size -lt 1 ]] && { rm -f "$backup_file"; log_error "$app_name - Backup too small"; return 1; }

    log_ok "$app_name - Saved (${size} KB)"
}

# ============================================================
# Audiobookshelf backup via API
# ============================================================
backup_audiobookshelf() {
    local app_url="$1"
    local api_key="$2"

    if [[ -z "$api_key" ]]; then
        log_skip "audiobookshelf - No API key"
        return 0
    fi

    log_info "audiobookshelf - Starting backup..."

    local app_backup_dir="${BACKUP_DIR}/audiobookshelf/${DATE}"
    mkdir -p "$app_backup_dir"

    # Create backup
    local response
    response=$(curl -sf -X POST "${app_url}/api/backups" \
        -H "Authorization: Bearer ${api_key}" 2>&1) || {
        log_error "audiobookshelf - Failed to create backup"
        return 1
    }

    local backup_id
    backup_id=$(echo "$response" | jq -r '.id // empty')
    [[ -z "$backup_id" ]] && { log_error "audiobookshelf - No backup ID returned"; return 1; }

    # Download backup
    local backup_file="${app_backup_dir}/audiobookshelf_${TIMESTAMP}.tar"
    curl -sf "${app_url}/api/backups/${backup_id}" \
        -H "Authorization: Bearer ${api_key}" -o "$backup_file" || {
        log_error "audiobookshelf - Failed to download"
        return 1
    }

    local size=$(($(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file") / 1024))
    [[ $size -lt 1 ]] && { rm -f "$backup_file"; log_error "audiobookshelf - Backup too small"; return 1; }

    log_ok "audiobookshelf - Saved (${size} KB)"
}

# ============================================================
# Jellyfin backup via filesystem (config directory)
# ============================================================
backup_jellyfin() {
    local config_mount="$1"

    if [[ ! -d "$config_mount" ]]; then
        log_skip "jellyfin - Config mount not found"
        return 0
    fi

    log_info "jellyfin - Starting filesystem backup..."

    local app_backup_dir="${BACKUP_DIR}/jellyfin/${DATE}"
    mkdir -p "$app_backup_dir"

    # Backup important config files only (not cache/transcodes)
    local backup_file="${app_backup_dir}/jellyfin_${TIMESTAMP}.tar.gz"

    # Create selective backup of config
    tar -czf "$backup_file" \
        -C "$config_mount" \
        --exclude='cache' \
        --exclude='transcodes' \
        --exclude='log' \
        --exclude='metadata' \
        . 2>/dev/null || {
        log_error "jellyfin - Failed to create archive"
        return 1
    }

    local size=$(($(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file") / 1024))
    [[ $size -lt 1 ]] && { rm -f "$backup_file"; log_error "jellyfin - Backup too small"; return 1; }

    log_ok "jellyfin - Saved (${size} KB)"
}

# ============================================================
# Generic filesystem backup
# ============================================================
backup_filesystem() {
    local app_name="$1"
    local source_dir="$2"
    local backup_subdir="${3:-}"
    local excludes="${4:-}"

    local source_path="$source_dir"
    [[ -n "$backup_subdir" ]] && source_path="${source_dir}/${backup_subdir}"

    if [[ ! -d "$source_path" ]]; then
        log_skip "$app_name - Source not found: $source_path"
        return 0
    fi

    log_info "$app_name - Starting filesystem backup..."

    local app_backup_dir="${BACKUP_DIR}/${app_name}/${DATE}"
    mkdir -p "$app_backup_dir"

    local backup_file="${app_backup_dir}/${app_name}_${TIMESTAMP}.tar.gz"

    # Build exclude args
    local exclude_args=""
    if [[ -n "$excludes" ]]; then
        for exc in $excludes; do
            exclude_args="$exclude_args --exclude=$exc"
        done
    fi

    if [[ -n "$backup_subdir" ]]; then
        tar -czf "$backup_file" -C "$source_dir" $exclude_args "$backup_subdir" 2>/dev/null || {
            log_error "$app_name - Failed to create archive"
            return 1
        }
    else
        tar -czf "$backup_file" -C "$source_dir" $exclude_args . 2>/dev/null || {
            log_error "$app_name - Failed to create archive"
            return 1
        }
    fi

    local size=$(($(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file") / 1024))
    [[ $size -lt 1 ]] && { rm -f "$backup_file"; log_error "$app_name - Backup too small"; return 1; }

    log_ok "$app_name - Saved (${size} KB)"
}

# ============================================================
# Cleanup old backups
# ============================================================
cleanup_old_backups() {
    local retention_days="${1:-30}"

    [[ "$retention_days" -le 0 ]] && { log_info "Retention disabled"; return 0; }

    log_info "Cleaning up backups older than ${retention_days} days..."

    local deleted
    deleted=$(find "$BACKUP_DIR" -type f \( -name "*.zip" -o -name "*.tar.gz" -o -name "*.tar" -o -name "*.json" -o -name "*.ini" \) -mtime +"$retention_days" -delete -print 2>/dev/null | wc -l)

    find "$BACKUP_DIR" -type d -empty -delete 2>/dev/null || true

    log_info "Cleaned up ${deleted} old backup(s)"
}

# ============================================================
# Main
# ============================================================
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║               Backuparr - Backup Process                   ║"
    echo "║              $(date '+%Y-%m-%d %H:%M:%S')                          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Servarr API backups
    [[ "${RADARR_ENABLED:-false}" == "true" ]] && \
        backup_servarr "radarr" "$RADARR_URL" "$RADARR_API_KEY" "${RADARR_API_VERSION:-v3}"

    [[ "${SONARR_ENABLED:-false}" == "true" ]] && \
        backup_servarr "sonarr" "$SONARR_URL" "$SONARR_API_KEY" "${SONARR_API_VERSION:-v3}"

    [[ "${PROWLARR_ENABLED:-false}" == "true" ]] && \
        backup_servarr "prowlarr" "$PROWLARR_URL" "$PROWLARR_API_KEY" "${PROWLARR_API_VERSION:-v1}"

    [[ "${LIDARR_ENABLED:-false}" == "true" ]] && \
        backup_servarr "lidarr" "$LIDARR_URL" "$LIDARR_API_KEY" "${LIDARR_API_VERSION:-v3}"

    [[ "${READARR_ENABLED:-false}" == "true" ]] && \
        backup_servarr "readarr" "$READARR_URL" "$READARR_API_KEY" "${READARR_API_VERSION:-v3}"

    # Sabnzbd
    [[ "${SABNZBD_ENABLED:-false}" == "true" ]] && \
        backup_sabnzbd "$SABNZBD_URL" "$SABNZBD_API_KEY"

    # Overseerr/Jellyseerr (seerr)
    [[ "${SEERR_ENABLED:-false}" == "true" ]] && \
        backup_overseerr "seerr" "$SEERR_URL" "$SEERR_API_KEY"

    # Audiobookshelf
    [[ "${AUDIOBOOKSHELF_ENABLED:-false}" == "true" ]] && \
        backup_audiobookshelf "$AUDIOBOOKSHELF_URL" "$AUDIOBOOKSHELF_API_KEY"

    # Jellyfin (filesystem)
    [[ "${JELLYFIN_ENABLED:-false}" == "true" ]] && \
        backup_jellyfin "${JELLYFIN_CONFIG_MOUNT:-/config/jellyfin}"

    # Bazarr (filesystem - backup dir)
    [[ "${BAZARR_ENABLED:-false}" == "true" ]] && \
        backup_filesystem "bazarr" "${BAZARR_CONFIG_MOUNT:-/config/bazarr}" "backup"

    # Tdarr (filesystem - config)
    [[ "${TDARR_ENABLED:-false}" == "true" ]] && \
        backup_filesystem "tdarr" "${TDARR_CONFIG_MOUNT:-/config/tdarr}" "" "cache logs"

    # Kapowarr (filesystem - config)
    [[ "${KAPOWARR_ENABLED:-false}" == "true" ]] && \
        backup_filesystem "kapowarr" "${KAPOWARR_CONFIG_MOUNT:-/config/kapowarr}" "" "cache"

    # LazyLibrarian (filesystem - config)
    [[ "${LAZYLIBRARIAN_ENABLED:-false}" == "true" ]] && \
        backup_filesystem "lazylibrarian" "${LAZYLIBRARIAN_CONFIG_MOUNT:-/config/lazylibrarian}" "" "cache"

    # Wizarr (filesystem - data)
    [[ "${WIZARR_ENABLED:-false}" == "true" ]] && \
        backup_filesystem "wizarr" "${WIZARR_CONFIG_MOUNT:-/config/wizarr}" ""

    # Tunarr (filesystem - config)
    [[ "${TUNARR_ENABLED:-false}" == "true" ]] && \
        backup_filesystem "tunarr" "${TUNARR_CONFIG_MOUNT:-/config/tunarr}" ""

    # Cleanup
    [[ "${RETENTION_ENABLED:-true}" == "true" ]] && \
        cleanup_old_backups "${RETENTION_DAYS:-30}"

    # Summary
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "Backup Summary"
    echo "════════════════════════════════════════════════════════════"
    du -sh "$BACKUP_DIR"/*/ 2>/dev/null || echo "No backups found"
    echo ""
    echo -e "Successful: ${GREEN}${SUCCESS}${NC}  |  Errors: ${RED}${ERRORS}${NC}"
    echo ""

    if [[ $ERRORS -gt 0 ]]; then
        log_warn "Completed with $ERRORS error(s)"
        exit 1
    fi

    log_ok "All backups completed successfully!"
}

main "$@"

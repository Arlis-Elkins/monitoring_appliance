#!/bin/bash

set -euo pipefail

APP_DIR="/opt/monitoring-appliance"

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root or with sudo."
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "Usage:"
    echo "  $0 <backup-file.tar.gz>"
    exit 1
fi

set -a
# shellcheck source=/dev/null
source "$APP_DIR/.env"
set +a

BACKUP_DIR="$MOUNT_POINT/$SMB_SUBFOLDER"
CREDS_FILE="$(mktemp)"
MOUNTED_HERE=false

cleanup() {
    if [[ "$MOUNTED_HERE" == true ]] && mountpoint -q "$MOUNT_POINT"; then
        umount "$MOUNT_POINT" || true
    fi
    rm -f "$CREDS_FILE"
}

trap cleanup EXIT

if ! mountpoint -q "$MOUNT_POINT"; then
    printf 'username=%s\npassword=%s\n' "$SMB_USER" "$SMB_PASS" > "$CREDS_FILE"

    echo "Mounting SMB share..."
    mkdir -p "$MOUNT_POINT"
    mount -t cifs "//$SMB_SERVER/$SMB_SHARE" "$MOUNT_POINT" \
        -o "credentials=$CREDS_FILE,iocharset=utf8,vers=$SMB_VERSION"
    MOUNTED_HERE=true
fi

BACKUP_FILE="$BACKUP_DIR/$(basename "$1")"

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "Backup file not found:"
    echo "  $BACKUP_FILE"
    exit 1
fi

echo "Verifying archive..."
if ! tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
    echo "Archive is corrupt or unreadable:"
    echo "  $BACKUP_FILE"
    exit 1
fi

cd "$APP_DIR"

echo "Stopping containers..."
docker compose down

echo "Removing existing Uptime Kuma volume..."
docker volume rm uptime-kuma || true

echo "Creating fresh volume..."
docker volume create uptime-kuma

echo "Restoring backup..."

docker run --rm \
    -v uptime-kuma:/restore \
    -v "$(dirname "$BACKUP_FILE"):/backup" \
    alpine \
    sh -c "tar xzf /backup/$(basename "$BACKUP_FILE") -C /restore"

echo "Starting containers..."
docker compose up -d

echo
echo "Restore complete."
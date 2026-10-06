#!/bin/bash

set -euo pipefail

APP_DIR="/opt/monitoring-appliance"

if [[ $# -ne 1 ]]; then
    echo "Usage:"
    echo "  $0 <backup-file.tar.gz>"
    exit 1
fi

set -a
source "$APP_DIR/.env"
set +a

BACKUP_DIR="$MOUNT_POINT/$SMB_SUBFOLDER"
CREDS_FILE="$(mktemp)"

cleanup() {
    if mountpoint -q "$MOUNT_POINT"; then
        umount "$MOUNT_POINT" || true
    fi
    rm -f "$CREDS_FILE"
}

trap cleanup EXIT

printf 'username=%s\npassword=%s\n' "$SMB_USER" "$SMB_PASS" > "$CREDS_FILE"

echo "Mounting SMB share..."
mkdir -p "$MOUNT_POINT"

mount -t cifs "//$SMB_SERVER/$SMB_SHARE" "$MOUNT_POINT" \
    -o "credentials=$CREDS_FILE,iocharset=utf8,vers=$SMB_VERSION"

if ! mountpoint -q "$MOUNT_POINT"; then
    echo "SMB mount failed"
    exit 1
fi

BACKUP_FILE="$BACKUP_DIR/$1"

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "Backup file not found:"
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
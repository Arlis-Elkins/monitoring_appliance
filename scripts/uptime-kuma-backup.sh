#!/bin/bash

set -euo pipefail

APP_DIR="/opt/monitoring-appliance"

set -a
source "$APP_DIR/.env"
set +a

BACKUP_DIR="$MOUNT_POINT/$SMB_SUBFOLDER"
ARCHIVE="uptime-kuma-$(date +%Y-%m-%d).tar.gz"
CREDS_FILE="$(mktemp)"

cleanup() {
    echo "Starting cleanup..."

    if ! docker ps --format '{{.Names}}' | grep -q '^uptime-kuma$'; then
        echo "Starting Uptime Kuma..."
        docker start uptime-kuma || true
    fi

    if mountpoint -q "$MOUNT_POINT"; then
        echo "Unmounting SMB share..."
        umount "$MOUNT_POINT" || true
    fi

    rm -f "$CREDS_FILE"
    echo "Cleanup complete."
}

trap cleanup EXIT

printf 'username=%s\npassword=%s\n' "$SMB_USER" "$SMB_PASS" > "$CREDS_FILE"

echo "Mounting SMB share..."
mkdir -p "$MOUNT_POINT"
mount -t cifs "//$SMB_SERVER/$SMB_SHARE" "$MOUNT_POINT" \
    -o "credentials=$CREDS_FILE,iocharset=utf8,vers=$SMB_VERSION"

mkdir -p "$BACKUP_DIR"

echo "Stopping Uptime Kuma..."
docker stop uptime-kuma

echo "Creating backup archive..."
docker run --rm \
    -v uptime-kuma:/data:ro \
    -v "$BACKUP_DIR":/backup \
    alpine tar czf "/backup/$ARCHIVE" -C /data .

echo "Starting Uptime Kuma..."
docker start uptime-kuma

echo "Removing backups older than $BACKUP_RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "uptime-kuma-*.tar.gz" -mtime +"$BACKUP_RETENTION_DAYS" -delete

sync
echo "Backup completed successfully."
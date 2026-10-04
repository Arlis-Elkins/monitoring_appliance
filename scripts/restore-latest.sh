#!/bin/bash

set -euo pipefail

APP_DIR="/opt/monitoring-appliance"
ASSUME_YES=false

case "${1:-}" in
    "")      ;;
    --yes)   ASSUME_YES=true ;;
    *)
        echo "Usage:"
        echo "  $0 [--yes]"
        exit 1
        ;;
esac

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root or with sudo."
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

LATEST="$(find "$BACKUP_DIR" -maxdepth 1 -name 'uptime-kuma-*.tar.gz' 2>/dev/null | sort | tail -n 1 || true)"

if [[ -z "$LATEST" ]]; then
    echo "No backups found in $BACKUP_DIR"
    exit 1
fi

echo "Newest backup: $LATEST"

if [[ "$ASSUME_YES" != true ]]; then
    read -r -p "This replaces the current Uptime Kuma data. Continue? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

"$APP_DIR/scripts/restore.sh" "$LATEST"
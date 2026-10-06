#!/bin/bash

set -euo pipefail

APP_DIR="/opt/monitoring-appliance"

echo "=================================================="
echo "Monitoring Appliance Installer"
echo "=================================================="

#
# Root check
#

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root or with sudo."
    exit 1
fi

#
# Install Docker if missing
#

if ! command -v docker >/dev/null 2>&1; then
    echo "Installing Docker..."

    curl -fsSL https://get.docker.com | sh

    systemctl enable docker
    systemctl start docker
fi

#
# Install Docker Compose plugin if needed
#

if ! docker compose version >/dev/null 2>&1; then
    echo "Installing Docker Compose plugin..."

    apt-get update
    apt-get install -y docker-compose-plugin
fi

#
# Install backup dependencies
#

echo "Installing backup dependencies..."
apt-get update -qq
apt-get install -y cifs-utils cron

#
# Create application directory
#

mkdir -p "$APP_DIR"

#
# Require a configured .env
#

if [[ ! -f "$APP_DIR/.env" ]]; then
    if [[ ! -f "$APP_DIR/sample.env" ]]; then
        echo "Neither .env nor sample.env found in $APP_DIR"
        exit 1
    fi

    cp "$APP_DIR/sample.env" "$APP_DIR/.env"
    chmod 600 "$APP_DIR/.env"

    echo
    echo "=================================================="
    echo ".env created from sample.env"
    echo "Edit it, then re-run this installer:"
    echo "  nano $APP_DIR/.env"
    echo "=================================================="
    echo
    exit 1
fi

chmod 600 "$APP_DIR/.env"

#
# Create Uptime Kuma volume if needed
#

if ! docker volume inspect uptime-kuma >/dev/null 2>&1; then
    echo "Creating Docker volume: uptime-kuma"
    docker volume create uptime-kuma
fi

#
# Create Hawser volume if needed
#

if ! docker volume inspect hawser-data >/dev/null 2>&1; then
    echo "Creating Docker volume: hawser-data"
    docker volume create hawser-data
fi

#
#Add User to Docker Group
#

echo "Adding user $USER to docker group..."
if ! groups "$USER" | grep -q "\bdocker\b"; then
    usermod -aG docker "$USER"
    echo "User $USER added to docker group. You may need to log out and back in for this to take effect."
fi

#
# Schedule weekly backup
#

set -a
source "$APP_DIR/.env"
set +a

echo "$BACKUP_SCHEDULE root $APP_DIR/scripts/uptime-kuma-backup.sh >> /var/log/uptime-kuma-backup.log 2>&1" \
    > /etc/cron.d/monitoring-appliance-backup
chmod 644 /etc/cron.d/monitoring-appliance-backup

#
# Pull latest images
#

cd "$APP_DIR"

echo "Pulling latest images..."
docker compose pull

echo
echo "Install complete. Start the appliance with:"
echo "  cd $APP_DIR && docker compose up -d"
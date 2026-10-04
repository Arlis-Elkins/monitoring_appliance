# Monitoring Appliance Recovery Guide

This document covers recovery of the ElkLab Monitoring Appliance hosted on Hudson.

The appliance is designed to be rebuilt from source control and restored from backup
with minimal manual configuration. Target recovery time: approximately 15 minutes.

Only Uptime Kuma data is backed up. Everything else (compose file, scripts, `.env`)
comes from the repository and your own configuration.

---

## Recovery Scenarios

| Situation | Procedure |
|---|---|
| SD card failed or appliance rebuilt from scratch | Scenario 1 |
| Restore the newest backup (fastest) | Scenario 2 |
| Roll back to a specific date, or latest backup is bad | Scenario 3 |

---

## Scenario 1 - Full Rebuild (SD Card Failure)

Use this when the SD card has failed, the OS is corrupted, hardware was replaced, or
you are rebuilding from scratch. This is the most common scenario.

### Step 1 - Install Debian

Install a fresh copy of Debian, then update and install Git:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install git -y
```

Set the host timezone so the backup schedule runs when you expect (cron uses host time):

```bash
sudo timedatectl set-timezone America/Chicago
```

### Step 2 - Clone Repository

```bash
sudo mkdir -p /opt/monitoring-appliance
sudo chown "$USER": /opt/monitoring-appliance

git clone https://github.com/Arlis-Elkins/monitoring_appliance.git /opt/monitoring-appliance
cd /opt/monitoring-appliance
```

### Step 3 - Configure Environment

```bash
cp sample.env .env
nano .env
```

Replace every placeholder with real values: the SMB share details (`SMB_SERVER`,
`SMB_SHARE`, `SMB_SUBFOLDER`, `SMB_USER`, `SMB_PASS`), `HAWSER_TOKEN`, and `TIMEZONE`.
See the Configuration section of [README.md](../README.md) for details.

### Step 4 - Install

```bash
sudo ./scripts/install.sh
```

This will:

- Install Docker, `cifs-utils`, and `cron` if missing
- Create the required Docker volumes
- Schedule the weekly backup job
- Pull the container images

The containers are started by the restore step, not by the installer.

### Step 5 - Restore Data

```bash
sudo ./scripts/restore-latest.sh
```

Review the selected backup, confirm, and the script restores it and starts the
containers. For unattended recovery, add `--yes`.

### Step 6 - Validate

```bash
docker ps
```

- Both `uptime-kuma` and `hawser` are running
- Uptime Kuma loads at `http://<host>:3001` with your monitors and history intact
- Hawser is reachable from your Dockhand server

---

## Scenario 2 - Restore Latest Backup

Use this when the latest backup is known good and you want the fastest recovery,
for example after damaged configuration or lost monitors.

```bash
sudo /opt/monitoring-appliance/scripts/restore-latest.sh
```

The script will:

1. Mount the backup share
2. Locate and display the newest backup archive
3. Ask for confirmation (skipped with `--yes`)
4. Replace the Uptime Kuma volume with the backup
5. Restart the containers and unmount the share

---

## Scenario 3 - Restore a Specific Backup

Use this to roll back to a particular date, recover a deleted monitor, or avoid a
bad latest backup.

The share is normally unmounted, so mount it first using the values in `.env`:

```bash
cd /opt/monitoring-appliance
set -a; source .env; set +a

sudo mkdir -p "$MOUNT_POINT"
sudo mount -t cifs "//$SMB_SERVER/$SMB_SHARE" "$MOUNT_POINT" \
    -o "username=$SMB_USER,password=$SMB_PASS,vers=$SMB_VERSION"

ls -lh "$MOUNT_POINT/$SMB_SUBFOLDER"
```

Restore the archive you want:

```bash
sudo ./scripts/restore.sh "$MOUNT_POINT/$SMB_SUBFOLDER/uptime-kuma-2026-10-03.tar.gz"
```

Then unmount:

```bash
sudo umount "$MOUNT_POINT"
```

The restore script will:

1. Stop the containers
2. Delete and recreate the Uptime Kuma volume (existing data is replaced)
3. Extract the selected archive
4. Restart the containers

---

## Backups

Backups are stored on the SMB share defined in `.env`, named
`uptime-kuma-YYYY-MM-DD.tar.gz` (for example, `uptime-kuma-2026-10-03.tar.gz`).
See [BACKUP.md](BACKUP.md) for schedule, retention, and verification.

---

## Disaster Recovery Summary

```bash
sudo apt install git -y

sudo mkdir -p /opt/monitoring-appliance
sudo chown "$USER": /opt/monitoring-appliance
git clone https://github.com/Arlis-Elkins/monitoring_appliance.git /opt/monitoring-appliance
cd /opt/monitoring-appliance

cp sample.env .env
nano .env

sudo ./scripts/install.sh
sudo ./scripts/restore-latest.sh --yes
```
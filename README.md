# Monitoring Appliance

Complete configuration for a Lab monitoring appliance.

## Services

- **Uptime Kuma**: self-hosted uptime monitoring and status dashboard.
- **Hawser**: lightweight remote Docker agent that lets a Dockhand server manage Docker hosts.

## Prerequisites

- A Debian or Ubuntu host (the installer uses `apt-get`)
- An SMB share for backups, configured in `.env`

The installer sets up Docker, the Compose plugin, `cifs-utils`, and `cron` if they are missing.

## Repository Structure

```text
monitoring_appliance/
├── compose.yml
├── sample.env
├── README.md
├── .gitignore
├── scripts/
│   ├── install.sh
│   ├── uptime-kuma-backup.sh
│   ├── restore.sh
│   └── restore-latest.sh
└── docs/
    ├── BACKUP.md
    └── RECOVERY.md
```

## Installation

The repository must live at `/opt/monitoring-appliance`; the scripts expect that path.

```bash
sudo mkdir -p /opt/monitoring-appliance
sudo chown "$USER": /opt/monitoring-appliance

git clone https://github.com/Arlis-Elkins/monitoring_appliance.git /opt/monitoring-appliance
cd /opt/monitoring-appliance

cp sample.env .env
nano .env

sudo ./scripts/install.sh
sudo docker compose up -d
```

`install.sh` pulls the images, creates the Docker volumes, and schedules the weekly
backup. It does not start the containers; the last command does. When recovering a
failed appliance, skip that command and follow [docs/RECOVERY.md](docs/RECOVERY.md),
where the restore step starts the containers for you.

After installation, the only addition to the tree above is the untracked `.env` file.

## Access

| Service     | Address                  |
|-------------|--------------------------|
| Uptime Kuma | `http://<host>:3001`     |
| Hawser      | `<host>:2376` (token-authenticated) |

Hawser has access to the host's Docker socket. Keep port 2376 on a trusted network and
never expose it to the internet.

## Configuration

The appliance uses two environment files, both in `/opt/monitoring-appliance/`:

| File         | Tracked by Git | Purpose                                                                  |
|--------------|----------------|--------------------------------------------------------------------------|
| `sample.env` | Yes            | Template listing every setting with placeholder values. Safe to commit.  |
| `.env`       | No             | Real configuration: credentials, tokens, and deployment-specific values. |

### Settings

Every setting in `sample.env` must be replaced with a real value in `.env`.

| Variable                | Description                                                  |
|-------------------------|--------------------------------------------------------------|
| `HAWSER_TOKEN`          | Authentication token for Hawser                              |
| `SMB_SERVER`            | Hostname or IP of the SMB backup server                      |
| `SMB_SHARE`             | Share name on that server                                    |
| `SMB_SUBFOLDER`         | Folder inside the share for backups (case-sensitive)         |
| `SMB_USER`              | Username for the share                                       |
| `SMB_PASS`              | Password for the share                                       |
| `SMB_VERSION`           | SMB protocol version for the mount (default `3.0`)           |
| `MOUNT_POINT`           | Local path where the share is mounted during backups         |
| `BACKUP_RETENTION_DAYS` | Backups older than this are deleted after each run           |
| `BACKUP_SCHEDULE`       | Cron expression for the backup job, in host time             |
| `TIMEZONE`              | Container timezone, for example `America/Chicago`            |

Keep string values in single quotes, as in `sample.env`, so passwords containing `#`,
`$`, or spaces are read correctly.

### Git behavior

- `.env` is excluded via `.gitignore` and must never be committed.
- Update `sample.env` whenever a new configuration option is introduced.

## Updating

```bash
cd /opt/monitoring-appliance
git pull
sudo ./scripts/install.sh
sudo docker compose up -d
```

## Backups

Uptime Kuma data is backed up weekly to the SMB share. See [docs/BACKUP.md](docs/BACKUP.md).

## Recovery

See [docs/RECOVERY.md](docs/RECOVERY.md).
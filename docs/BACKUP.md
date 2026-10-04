# Backup Documentation

## What Is Backed Up

The Uptime Kuma data volume (`uptime-kuma`), saved as a compressed archive named
`uptime-kuma-YYYY-MM-DD.tar.gz`. Hawser holds no data worth backing up and is not included.

Uptime Kuma is stopped while the archive is created, so expect a brief monitoring gap
during each backup. A second backup on the same day overwrites the first.

## Schedule

Defined by `BACKUP_SCHEDULE` in `.env` (cron syntax). The default is every Friday at 02:00
host time. `install.sh` writes the schedule to `/etc/cron.d/monitoring-appliance-backup`,
so re-run it after changing the value.

## Target

The SMB share defined in `.env` (`SMB_SERVER`, `SMB_SHARE`, `SMB_SUBFOLDER`). The share is
mounted at `MOUNT_POINT` only for the duration of the backup, then unmounted.

Backups older than `BACKUP_RETENTION_DAYS` (default 56) are deleted after each run.

## Manual Backup

```bash
sudo /opt/monitoring-appliance/scripts/uptime-kuma-backup.sh
```

## Verification

Check the log for the most recent run:

```bash
sudo tail -n 20 /var/log/uptime-kuma-backup.log
```

A successful run ends with `Backup completed successfully.` and lists the new archive
with its size just above it.

To browse the backups themselves, open the share from another machine, or mount it
manually using the values in `.env`. The mount point is empty between runs because the
share is unmounted after each backup.

## Restoring

See [RECOVERY.md](RECOVERY.md).
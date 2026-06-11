#!/bin/bash
# Enable nullglob so empty directories don't cause globbing literal errors
shopt -s nullglob

DATE=$(date +%Y-%m-%d)
LOG_FILE="/rclone/logs/opencloud/backup-${DATE}.log"

# Redirect all stdout and stderr to the timestamped log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== OpenCloud Backup Started: $(date) ==="

# Define Paths
# OpenCloud data: config, data, and user storage
SOURCE_CONFIG="/opencloud/data/config/"
SOURCE_DATA="/opencloud/data/data/"
SOURCE_USERS="/opencloud/users/"

LOCAL_DEST="/rsync/opencloud/current/"
LOCAL_ARCHIVE="/rsync/opencloud/archive/${DATE}"

CLOUD_DEST="gdrive:opencloud/current/"
CLOUD_ARCHIVE="gdrive:opencloud/archive/${DATE}"

RCLONE_CONF="/rclone/rclone.conf"

# Containers to stop for consistent backup
CONTAINERS="opencloud collaboration onlyoffice"

# Ensure local directories exist
mkdir -p "$LOCAL_DEST/config" "$LOCAL_DEST/data" "$LOCAL_DEST/users" "/rsync/opencloud/archive"
mkdir -p "$(dirname $LOG_FILE)"

# 0. STOP OPENCLOUD FOR CONSISTENT BACKUP
echo ">>> Stopping OpenCloud containers for consistent backup..."
for container in $CONTAINERS; do
    echo "Stopping $container..."
    docker stop "$container" 2>/dev/null || echo "Warning: $container not running"
done

# Wait for containers to fully stop
sleep 5

# 1. LOCAL RSYNC BACKUP
echo ">>> Starting local rsync backup..."

echo "  - Syncing config..."
rsync -ahv --delete --backup --backup-dir="$LOCAL_ARCHIVE/config" \
  "$SOURCE_CONFIG" "$LOCAL_DEST/config/"

echo "  - Syncing data..."
rsync -ahv --delete --backup --backup-dir="$LOCAL_ARCHIVE/data" \
  "$SOURCE_DATA" "$LOCAL_DEST/data/"

echo "  - Syncing users..."
rsync -ahv --delete --backup --backup-dir="$LOCAL_ARCHIVE/users" \
  "$SOURCE_USERS" "$LOCAL_DEST/users/"

# 2. RESTART OPENCLOUD (minimize downtime - cloud backup runs after restart)
echo ">>> Restarting OpenCloud containers..."
for container in $CONTAINERS; do
    echo "Starting $container..."
    docker start "$container" 2>/dev/null || echo "Warning: failed to start $container"
done

echo ">>> OpenCloud is back online. Continuing with cloud backup..."

# 3. CLOUD RCLONE BACKUP (from local rsync copy, not live data)
echo ">>> Starting cloud rclone backup to Google Drive..."
rclone sync "$LOCAL_DEST" "$CLOUD_DEST" \
  --backup-dir="$CLOUD_ARCHIVE" \
  --config="$RCLONE_CONF" -v

# 4. 30-DAY RETENTION POLICY
echo ">>> Cleaning up archives older than 30 days..."
CUTOFF_DATE=$(date -d "30 days ago" +%Y-%m-%d)

# Purge old local archives
for dir in /rsync/opencloud/archive/*; do
    if [ -d "$dir" ]; then
        dirname=$(basename "$dir")
        if [[ "$dirname" < "$CUTOFF_DATE" ]]; then
            echo "Deleting old local archive: $dir"
            rm -rf "$dir"
        fi
    fi
done

# Purge old cloud archives
rclone lsf --dirs-only "gdrive:opencloud/archive/" --config="$RCLONE_CONF" | while read -r dir; do
    dirname=${dir%/}
    if [[ "$dirname" < "$CUTOFF_DATE" ]]; then
        echo "Deleting old cloud archive: $dirname"
        rclone purge "gdrive:opencloud/archive/$dirname" --config="$RCLONE_CONF"
    fi
done

echo "=== OpenCloud Backup Completed: $(date) ==="

#!/bin/bash
# Enable nullglob so empty directories don't cause globbing literal errors
shopt -s nullglob

DATE=$(date +%Y-%m-%d)
LOG_FILE="/rclone/logs/opencloud/dryrun-${DATE}.log"

# Redirect all stdout and stderr to the timestamped log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== OpenCloud DRY RUN Started: $(date) ==="
echo "NOTICE: No files will be copied or deleted. Containers will NOT be stopped."

# Define Paths
SOURCE_CONFIG="/opencloud/data/config/"
SOURCE_DATA="/opencloud/data/data/"
SOURCE_USERS="/opencloud/users/"

LOCAL_DEST="/rsync/opencloud/current/"
LOCAL_ARCHIVE="/rsync/opencloud/archive/${DATE}"

CLOUD_DEST="gdrive:opencloud/current/"
CLOUD_ARCHIVE="gdrive:opencloud/archive/${DATE}"

RCLONE_CONF="/rclone/rclone.conf"

# Ensure local directories exist
mkdir -p "$LOCAL_DEST/config" "$LOCAL_DEST/data" "$LOCAL_DEST/users" "/rsync/opencloud/archive"
mkdir -p "$(dirname $LOG_FILE)"

# 1. LOCAL RSYNC BACKUP (DRY RUN)
echo ">>> [DRY RUN] Starting local rsync backup..."

echo "  - Config..."
rsync -ahv --dry-run --delete --backup --backup-dir="$LOCAL_ARCHIVE/config" \
  "$SOURCE_CONFIG" "$LOCAL_DEST/config/"

echo "  - Data..."
rsync -ahv --dry-run --delete --backup --backup-dir="$LOCAL_ARCHIVE/data" \
  "$SOURCE_DATA" "$LOCAL_DEST/data/"

echo "  - Users..."
rsync -ahv --dry-run --delete --backup --backup-dir="$LOCAL_ARCHIVE/users" \
  "$SOURCE_USERS" "$LOCAL_DEST/users/"

# 2. CLOUD RCLONE BACKUP (DRY RUN)
echo ">>> [DRY RUN] Starting cloud rclone backup to Google Drive..."
rclone sync "$LOCAL_DEST" "$CLOUD_DEST" \
  --dry-run \
  --backup-dir="$CLOUD_ARCHIVE" \
  --config="$RCLONE_CONF" -v

# 3. 30-DAY RETENTION POLICY (DRY RUN)
echo ">>> [DRY RUN] Simulating cleanup of archives older than 30 days..."
CUTOFF_DATE=$(date -d "30 days ago" +%Y-%m-%d)

for dir in /rsync/opencloud/archive/*; do
    if [ -d "$dir" ]; then
        dirname=$(basename "$dir")
        if [[ "$dirname" < "$CUTOFF_DATE" ]]; then
            echo "[DRY RUN] Would delete old local archive: $dir"
        fi
    fi
done

rclone lsf --dirs-only "gdrive:opencloud/archive/" --config="$RCLONE_CONF" | while read -r dir; do
    dirname=${dir%/}
    if [[ "$dirname" < "$CUTOFF_DATE" ]]; then
        echo "[DRY RUN] Would delete old cloud archive: $dirname"
    fi
done

echo "=== OpenCloud DRY RUN Completed: $(date) ==="

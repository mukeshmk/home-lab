#!/bin/bash
# Enable nullglob so empty directories don't cause globbing literal errors
shopt -s nullglob

DATE=$(date +%Y-%m-%d)
LOG_FILE="/rclone/logs/immich/backup-${DATE}.log"

# Redirect all stdout and stderr to the timestamped log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Immich Backup Started: $(date) ==="

# Define Paths
SOURCE_DIR="/immich/"
LOCAL_DEST="/rsync/immich/current/"
LOCAL_ARCHIVE="/rsync/immich/archive/${DATE}"
CLOUD_DEST="gdrive:immich/current/"
CLOUD_ARCHIVE="gdrive:immich/archive/${DATE}"
RCLONE_CONF="/rclone/rclone.conf"

# Ensure local directories exist
mkdir -p "$LOCAL_DEST" "/rsync/immich/archive"

# 1. LOCAL RSYNC BACKUP
echo ">>> Starting local rsync backup..."
rsync -ahv --delete --backup --backup-dir="$LOCAL_ARCHIVE" \
  --exclude="/thumbs/" \
  --exclude="/encoded-video/" \
  --exclude="/upload/" \
  --exclude="/profile/" \
  "$SOURCE_DIR" "$LOCAL_DEST"

# 2. CLOUD RCLONE BACKUP
echo ">>> Starting cloud rclone backup to Google Drive..."
rclone sync "$SOURCE_DIR" "$CLOUD_DEST" \
  --backup-dir="$CLOUD_ARCHIVE" \
  --exclude="/thumbs/**" \
  --exclude="/encoded-video/**" \
  --exclude="/upload/**" \
  --exclude="/profile/**" \
  --config="$RCLONE_CONF" -v

# 3. 90-DAY RETENTION POLICY
echo ">>> Cleaning up archives older than 90 days..."
CUTOFF_DATE=$(date -d "90 days ago" +%Y-%m-%d)

# Purge old local archives
for dir in /rsync/immich/archive/*; do
    if [ -d "$dir" ]; then
        dirname=$(basename "$dir")
        # Standard bash string comparison works perfectly for YYYY-MM-DD
        if [[ "$dirname" < "$CUTOFF_DATE" ]]; then
            echo "Deleting old local archive: $dir"
            rm -rf "$dir"
        fi
    fi
done

# Purge old cloud archives
rclone lsf --dirs-only "gdrive:immich/archive/" --config="$RCLONE_CONF" | while read -r dir; do
    dirname=${dir%/} # Strip trailing slash
    if [[ "$dirname" < "$CUTOFF_DATE" ]]; then
        echo "Deleting old cloud archive: $dirname"
        rclone purge "gdrive:immich/archive/$dirname" --config="$RCLONE_CONF"
    fi
done

echo "=== Immich Backup Completed: $(date) ==="

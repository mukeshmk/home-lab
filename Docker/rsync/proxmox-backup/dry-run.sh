#!/bin/bash
# Enable nullglob so empty directories don't cause globbing literal errors
shopt -s nullglob

DATE=$(date +%Y-%m-%d)
LOG_FILE="/rclone/logs/proxmox/dryrun-${DATE}.log"

# Redirect all stdout and stderr to the timestamped log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Proxmox DRY RUN Started: $(date) ==="
echo "NOTICE: No files will be copied or deleted."

# Define Paths
SOURCE_DIR="/backups/"
LOCAL_DEST="/rsync/proxmox/current/"
LOCAL_ARCHIVE="/rsync/proxmox/archive/${DATE}"
CLOUD_DEST="gdrive:proxmox/current/"
CLOUD_ARCHIVE="gdrive:proxmox/archive/${DATE}"
RCLONE_CONF="/rclone/rclone.conf"

# Ensure local directories exist
mkdir -p "$LOCAL_DEST" "/rsync/proxmox/archive"

# 1. LOCAL RSYNC BACKUP (DRY RUN)
echo ">>> [DRY RUN] Starting local rsync backup..."
rsync -ahv --dry-run --delete --backup --backup-dir="$LOCAL_ARCHIVE" \
  "$SOURCE_DIR" "$LOCAL_DEST"

# 2. CLOUD RCLONE BACKUP (DRY RUN)
echo ">>> [DRY RUN] Starting cloud rclone backup to Google Drive..."
rclone sync "$SOURCE_DIR" "$CLOUD_DEST" \
  --dry-run \
  --backup-dir="$CLOUD_ARCHIVE" \
  --config="$RCLONE_CONF" -v

# 3. 30-DAY RETENTION POLICY (DRY RUN)
echo ">>> [DRY RUN] Simulating cleanup of archives older than 30 days..."
CUTOFF_DATE=$(date -d "30 days ago" +%Y-%m-%d)

# Simulate purging old local archives
for dir in /rsync/proxmox/archive/*; do
    if [ -d "$dir" ]; then
        dirname=$(basename "$dir")
        if [[ "$dirname" < "$CUTOFF_DATE" ]]; then
            echo "[DRY RUN] Would delete old local archive: $dir"
            # rm -rf "$dir"  <-- Commented out for safety
        fi
    fi
done

# Simulate purging old cloud archives
rclone lsf --dirs-only "gdrive:proxmox/archive/" --config="$RCLONE_CONF" | while read -r dir; do
    dirname=${dir%/} # Strip trailing slash
    if [[ "$dirname" < "$CUTOFF_DATE" ]]; then
        echo "[DRY RUN] Would delete old cloud archive: $dirname"
        rclone purge "gdrive:proxmox/archive/$dirname" --dry-run --config="$RCLONE_CONF"
    fi
done

echo "=== Proxmox DRY RUN Completed: $(date) ==="

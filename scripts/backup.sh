#!/bin/bash
set -euo pipefail

SRC="/var/www/html"
DEST="$HOME/backups"
STAMP=$(date +%Y-%m-%d_%H%M)
FILE="$DEST/site_$STAMP.tar.gz"

tar -czf "$FILE" "$SRC"
echo "$(date): backup created $FILE" >> "$DEST/backup.log"

ls -1t "$DEST"/site_*.tar.gz | tail -n +8 | xargs -r rm --

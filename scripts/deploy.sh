#!/bin/bash
set -euo pipefail

REPO="$HOME/shophub-devops"
TARGET="/var/www/shophub"
MIN_SIZE="${MIN_SIZE:-200}"

cd "$REPO"
git pull

SIZE=$(wc -c < site/index.html)
if [ "$SIZE" -lt "$MIN_SIZE" ]; then
  echo "ERROR: site/index.html is only $SIZE bytes (minimum $MIN_SIZE). Deploy stopped."
  exit 1
fi

sudo cp -r site/. "$TARGET/"
sudo nginx -t
sudo systemctl reload nginx
curl -fsS -o /dev/null http://localhost
echo "Deploy OK: $SIZE bytes served from $TARGET"

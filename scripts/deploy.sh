#!/bin/bash
set -euo pipefail

REPO="$HOME/shophub-devops"
NAME="shophub"
MIN_SIZE="${MIN_SIZE:-200}"

cd "$REPO"
git pull

SIZE=$(wc -c < site/index.html)
if [ "$SIZE" -lt "$MIN_SIZE" ]; then
  echo "ERROR: site/index.html is only $SIZE bytes (minimum $MIN_SIZE). Deploy stopped."
  exit 1
fi

TAG=$(git rev-parse --short HEAD)
sudo docker build -t "$NAME:$TAG" .

sudo docker stop "$NAME" || true
sudo docker rm "$NAME" || true
sudo docker run -d --name "$NAME" --restart unless-stopped -p 80:80 "$NAME:$TAG"

sleep 2
curl -fsS -o /dev/null http://localhost
echo "Deploy OK: $SIZE bytes, image $NAME:$TAG"

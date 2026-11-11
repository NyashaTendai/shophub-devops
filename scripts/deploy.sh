#!/bin/bash
set -euo pipefail

if [ "$(hostname)" != "linux-lab" ]; then
  echo "ERROR: run this on the VM (linux-lab), not here. This is: $(hostname)"
  exit 1
fi

main() {
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

  export TAG
  TAG=$(git rev-parse --short HEAD)
  docker compose up -d --build

  sleep 2
  curl -fsS -o /dev/null http://localhost
  echo "Deploy OK: $SIZE bytes, image $NAME:$TAG"
}

main "$@"
exit

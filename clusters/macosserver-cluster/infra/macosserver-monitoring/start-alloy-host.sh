#!/bin/sh
set -eu

ENV_FILE="$HOME/.config/grafana/alloy-cloud.env"
if [ ! -r "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

exec /usr/local/bin/alloy run \
  --server.http.listen-addr=127.0.0.1:12346 \
  --storage.path="$HOME/.local/share/grafana-alloy" \
  /Users/agolovko/.config/grafana/alloy-host-config.alloy

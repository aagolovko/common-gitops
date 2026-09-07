#!/bin/sh
set -eu
exec /usr/bin/python3 "$HOME/.config/grafana/cloudflare-health.py"

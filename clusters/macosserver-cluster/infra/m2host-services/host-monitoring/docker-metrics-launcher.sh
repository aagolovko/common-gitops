#!/bin/sh
set -eu
exec /usr/bin/python3 "$HOME/.config/grafana/docker-metrics.py"

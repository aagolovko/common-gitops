#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h}"
config_dir="${HOME}/.config/grafana"
data_dir="${HOME}/.local/share/grafana-alloy"

if [[ -f "${HOME}/.env" ]]; then
  set -a
  source "${HOME}/.env"
  set +a
fi

host_name="${1:-$(scutil --get LocalHostName 2>/dev/null || hostname -s)}"
cluster_name="${ALLOY_CLUSTER_NAME:-${host_name}-cluster}"
grafana_url="${GRAFANA_CLOUD_REMOTE_WRITE_URL:-https://prometheus-prod-24-prod-eu-west-2.grafana.net/api/prom/push}"
grafana_user="${GRAFANA_CLOUD_USER:-1034855}"
grafana_token="${GRAFANA_CLOUD_TOKEN:-${GRAFANA_K8S_TOKEN:-}}"

if [[ -z "$grafana_token" ]]; then
  print -u2 "Missing GRAFANA_CLOUD_TOKEN or GRAFANA_K8S_TOKEN in ~/.env"
  exit 1
fi

mkdir -p "$config_dir" "$data_dir" "$HOME/Library/LaunchAgents"
cp "$repo_dir/alloy-host-config.alloy" "$config_dir/alloy-host-config.alloy"

cat > "$config_dir/alloy-cloud.env" <<EOF
GRAFANA_CLOUD_REMOTE_WRITE_URL=${grafana_url}
GRAFANA_CLOUD_USER=${grafana_user}
GRAFANA_CLOUD_TOKEN=${grafana_token}
ALLOY_HOST_NAME=${host_name}
ALLOY_CLUSTER_NAME=${cluster_name}
ALLOY_TEXTFILE_DIRECTORY=${data_dir}
EOF
chmod 600 "$config_dir/alloy-cloud.env"

cat > "$config_dir/alloy-host-launcher.sh" <<'EOF'
#!/bin/zsh
set -euo pipefail
set -a
source "$HOME/.config/grafana/alloy-cloud.env"
set +a
exec /opt/homebrew/bin/alloy run "$HOME/.config/grafana/alloy-host-config.alloy" \
  --storage.path="$HOME/.local/share/grafana-alloy/data" \
  --server.http.listen-addr=127.0.0.1:12346
EOF
chmod 700 "$config_dir/alloy-host-launcher.sh"

cp "$repo_dir/docker-metrics.py" "$config_dir/docker-metrics.py"
cp "$repo_dir/cloudflare-health.py" "$config_dir/cloudflare-health.py"
sed -i '' "s#__HOME__#${HOME}#g" "$config_dir/docker-metrics.py" "$config_dir/cloudflare-health.py"
cat > "$config_dir/docker-metrics-launcher.sh" <<'EOF'
#!/bin/sh
set -eu
exec /usr/bin/python3 "$HOME/.config/grafana/docker-metrics.py"
EOF
cat > "$config_dir/cloudflare-health-launcher.sh" <<'EOF'
#!/bin/sh
set -eu
exec /usr/bin/python3 "$HOME/.config/grafana/cloudflare-health.py"
EOF
chmod 700 "$config_dir/docker-metrics-launcher.sh" "$config_dir/cloudflare-health-launcher.sh"

cat > "$HOME/Library/LaunchAgents/com.grafana.alloy-host.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.grafana.alloy-host</string>
  <key>ProgramArguments</key><array><string>${config_dir}/alloy-host-launcher.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>${config_dir}/alloy-host.log</string>
  <key>StandardErrorPath</key><string>${config_dir}/alloy-host.error.log</string>
</dict></plist>
EOF

launchctl bootout "gui/$(id -u)/com.grafana.alloy-m2host" 2>/dev/null || true
if launchctl print "gui/$(id -u)/com.grafana.alloy-host" >/dev/null 2>&1; then
  launchctl kickstart -k "gui/$(id -u)/com.grafana.alloy-host"
else
  launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.grafana.alloy-host.plist"
fi

for service in com.grafana.docker-metrics com.grafana.cloudflare-health; do
  launchctl bootout "gui/$(id -u)/${service}" 2>/dev/null || true
done
cp "$repo_dir/com.grafana.docker-metrics.plist" "$HOME/Library/LaunchAgents/com.grafana.docker-metrics.plist"
cp "$repo_dir/com.grafana.cloudflare-health.plist" "$HOME/Library/LaunchAgents/com.grafana.cloudflare-health.plist"
sed -i '' "s#__HOME__#${HOME}#g" "$HOME/Library/LaunchAgents/com.grafana.docker-metrics.plist" "$HOME/Library/LaunchAgents/com.grafana.cloudflare-health.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.grafana.docker-metrics.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.grafana.cloudflare-health.plist"

# Migrate the legacy fixed-name exporter into the renamed Compose project.
if docker inspect fritz-exporter >/dev/null 2>&1; then
  docker rm -f fritz-exporter
fi
docker compose --project-name host-monitoring --file "$repo_dir/docker-compose.yml" up -d
print "Installed host monitoring for ${host_name} (${cluster_name})."

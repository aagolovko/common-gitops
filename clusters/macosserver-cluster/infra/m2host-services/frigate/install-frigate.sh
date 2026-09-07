#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h}"
launch_agent="${HOME}/Library/LaunchAgents/com.agolovko.frigate.plist"

mkdir -p "${HOME}/Library/LaunchAgents"

cat > "$launch_agent" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.agolovko.frigate</string>
  <key>RunAtLoad</key><true/>
  <key>WorkingDirectory</key><string>${repo_dir}</string>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key>
    <string>/Applications/Docker.app/Contents/Resources/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>ProgramArguments</key><array>
    <string>/Applications/Docker.app/Contents/Resources/bin/docker</string>
    <string>compose</string><string>up</string>
  </array>
  <key>StandardOutPath</key><string>/tmp/frigate-launchd.out.log</string>
  <key>StandardErrorPath</key><string>/tmp/frigate-launchd.err.log</string>
</dict></plist>
EOF

launchctl bootout "gui/$(id -u)/com.agolovko.frigate" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$launch_agent"
docker compose --project-name frigate --file "$repo_dir/docker-compose.yml" up -d
print "Installed Frigate from ${repo_dir}."

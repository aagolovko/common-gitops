#!/usr/bin/env python3
"""Synthetic Cloudflare Tunnel and public-route health metrics."""
import os
import subprocess
import time
import urllib.request

OUT = os.path.expanduser("~/.local/share/grafana-alloy/cloudflare.prom")
ROUTES = (
    ("n8n", "https://n8n.agolovko.net/healthz", "200"),
    ("schnapper", "https://schnapper.agolovko.net/", "200"),
    ("home_assistant", "https://home-assistant.agolovko.net/", "200"),
)

def esc(value):
    return value.replace("\\", "\\\\").replace('"', '\\"')

def main():
    lines = [
        "# HELP cloudflare_tunnel_process_up Whether the local cloudflared process exists.",
        "# TYPE cloudflare_tunnel_process_up gauge",
        "# HELP cloudflare_public_route_up Whether a public Cloudflare route returned the expected status.",
        "# TYPE cloudflare_public_route_up gauge",
        "# HELP cloudflare_public_route_response_seconds Public route response time.",
        "# TYPE cloudflare_public_route_response_seconds gauge",
        "# HELP cloudflare_public_route_dns_up Whether the public route hostname resolved.",
        "# TYPE cloudflare_public_route_dns_up gauge",
    ]
    process_up = subprocess.run(["/usr/bin/pgrep", "-x", "cloudflared"], stdout=subprocess.DEVNULL).returncode == 0
    lines.append(f"cloudflare_tunnel_process_up{{tunnel=\"0412b841-0052-4cd7-b9f2-5ef6fe1954c4\"}} {int(process_up)}")
    for name, url, expected in ROUTES:
        start = time.monotonic()
        status = 0
        resolved = 0
        try:
            request = urllib.request.Request(url, method="GET", headers={"User-Agent": "macosserver-monitor/1.0"})
            with urllib.request.urlopen(request, timeout=8) as response:
                status = response.status
            resolved = 1
        except Exception as exc:
            if getattr(exc, "code", None):
                status = exc.code
                resolved = 1
            else:
                resolved = 1 if "Name or service not known" not in str(exc) else 0
        elapsed = time.monotonic() - start
        labels = f'route="{esc(name)}",hostname="{esc(url.split("/")[2])}"'
        lines.append(f"cloudflare_public_route_up{{{labels}}} {int(str(status) == expected)}")
        lines.append(f"cloudflare_public_route_response_seconds{{{labels}}} {elapsed:.6f}")
        lines.append(f"cloudflare_public_route_dns_up{{{labels}}} {resolved}")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tmp = OUT + ".tmp"
    with open(tmp, "w") as stream:
        stream.write("\n".join(lines) + "\n")
    os.replace(tmp, OUT)

if __name__ == "__main__":
    main()

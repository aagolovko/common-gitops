#!/usr/bin/env python3
"""Expose Docker API stats as a small Prometheus textfile collector."""
import json
import os
import subprocess
import time

OUT = os.path.expanduser("~/.local/share/grafana-alloy/docker.prom")
DOCKER = "/Applications/Docker.app/Contents/Resources/bin/docker"

def docker(*args):
    return subprocess.check_output([DOCKER, *args], text=True)

def label(value):
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

def main():
    containers = [json.loads(line) for line in docker("ps", "--format", "{{json .}}").splitlines()]
    lines = [
        "# HELP docker_container_up Whether the container is running.",
        "# TYPE docker_container_up gauge",
        "# HELP docker_container_restarts_total Container restart count.",
        "# TYPE docker_container_restarts_total gauge",
        "# HELP docker_container_created_seconds Container creation timestamp.",
        "# TYPE docker_container_created_seconds gauge",
    ]
    stats_by_name = {}
    for line in docker("stats", "--no-stream", "--format", "{{json .}}").splitlines():
        item = json.loads(line)
        stats_by_name[item.get("Name")] = item
    infos = json.loads(docker("inspect", *[c["ID"] for c in containers]))
    for c in containers:
        cid = c["ID"]
        name = c["Names"]
        info = next((item for item in infos if item.get("Id", "").startswith(cid)), {})
        stats = stats_by_name.get(name, {})
        state = info.get("State", {})
        created = info.get("Created", "")
        try:
            created_seconds = time.mktime(time.strptime(created[:19], "%Y-%m-%dT%H:%M:%S"))
        except Exception:
            created_seconds = 0
        l = f'container_id="{label(cid[:12])}",container_name="{label(name)}"'
        lines.append(f"docker_container_up{{{l}}} {1 if state.get('Running') else 0}")
        lines.append(f"docker_container_restarts_total{{{l}}} {state.get('RestartCount', 0)}")
        lines.append(f"docker_container_created_seconds{{{l}}} {created_seconds}")
        def num(value):
            value = value.split("/")[0].strip().replace("%", "") if value else "0"
            units = {"KiB": 1024, "MiB": 1024**2, "GiB": 1024**3, "TiB": 1024**4, "Ki": 1024, "Mi": 1024**2, "Gi": 1024**3, "Ti": 1024**4, "kB": 1000, "KB": 1000, "MB": 1000**2, "GB": 1000**3, "B": 1}
            for unit, multiplier in units.items():
                if value.endswith(unit):
                    return float(value[:-len(unit)].strip()) * multiplier
            return float(value)
        lines.append(f"docker_container_cpu_percent{{{l}}} {num(stats.get('CPUPerc'))}")
        lines.append(f"docker_container_memory_usage_bytes{{{l}}} {num(stats.get('MemUsage', '').split(' / ')[0])}")
        lines.append(f"docker_container_memory_percent{{{l}}} {num(stats.get('MemPerc'))}")
        lines.append(f"docker_container_network_receive_bytes_total{{{l}}} {num(stats.get('NetIO', '').split(' / ')[0])}")
        lines.append(f"docker_container_network_transmit_bytes_total{{{l}}} {num(stats.get('NetIO', '').split(' / ')[-1])}")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tmp = OUT + ".tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(lines) + "\n")
    os.replace(tmp, OUT)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Write the current public egress IP as a Prometheus textfile metric."""

import os
import tempfile
import urllib.request


OUTPUT = os.path.expanduser("~/.local/share/grafana-alloy/fritz-public-ip.prom")


def main() -> None:
    try:
        request = urllib.request.Request(
            "https://api.ipify.org",
            headers={"User-Agent": "host-monitoring/1.0"},
        )
        ip = urllib.request.urlopen(request, timeout=10).read().decode().strip()
        if not ip:
            raise ValueError("empty public IP response")
        content = (
            "# HELP fritz_external_ip_info Current public egress IP of the router.\n"
            "# TYPE fritz_external_ip_info gauge\n"
            f'fritz_external_ip_info{{ip="{ip}"}} 1\n'
        )
    except Exception:
        content = (
            "# HELP fritz_external_ip_info Current public egress IP of the router.\n"
            "# TYPE fritz_external_ip_info gauge\n"
        )

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=os.path.dirname(OUTPUT), prefix=".fritz-public-ip-")
    with os.fdopen(fd, "w") as output:
        output.write(content)
    os.replace(temporary, OUTPUT)


if __name__ == "__main__":
    main()

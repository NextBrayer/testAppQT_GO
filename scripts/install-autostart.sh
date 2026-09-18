#!/usr/bin/env bash
# Installs Test Platform to start at boot. Run once as root on the board.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
START_SCRIPT="$ROOT_DIR/scripts/start-test-platform.sh"

[[ "${EUID}" -eq 0 ]] || { echo "Run: sudo bash scripts/install-autostart.sh" >&2; exit 1; }
chmod +x "$START_SCRIPT"

if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
  cat >/etc/systemd/system/test-platform.service <<UNIT
[Unit]
Description=Test Platform board application
After=multi-user.target

[Service]
Type=simple
WorkingDirectory=$ROOT_DIR
ExecStart=/bin/bash $START_SCRIPT
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable test-platform.service
  echo "Installed systemd service: test-platform.service"
  echo "Start now: sudo systemctl start test-platform.service"
else
  cat >/etc/init.d/S99test-platform <<INIT
#!/bin/sh
case "\$1" in
  start) /bin/bash "$START_SCRIPT" >/var/log/test-platform.log 2>&1 & ;;
  stop)  killall boardd-qml-client 2>/dev/null || true ;;
esac
INIT
  chmod +x /etc/init.d/S99test-platform
  echo "Installed BusyBox init script: /etc/init.d/S99test-platform"
  echo "It will run at the next boot. Start now: sudo /etc/init.d/S99test-platform start"
fi

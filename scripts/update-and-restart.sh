#!/usr/bin/env bash
# Rebuild everything after git pull, then restart the boot service.
# Run: bash scripts/update-and-restart.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v go >/dev/null || { echo "Go compiler is missing." >&2; exit 1; }
command -v cmake >/dev/null || { echo "CMake is missing." >&2; exit 1; }

echo "Building boardd..."
(
  cd "$ROOT_DIR/boardd"
  CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o boardd .
)

echo "Building Qt client..."
cmake -S "$ROOT_DIR/qt-client" -B "$ROOT_DIR/qt-client/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$ROOT_DIR/qt-client/build" -j"$(nproc)"

if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
  if ! systemctl cat test-platform.service >/dev/null 2>&1; then
    echo "Installing the boot service..."
    sudo bash "$ROOT_DIR/scripts/install-autostart.sh"
  fi
  echo "Restarting Test Platform..."
  sudo systemctl restart test-platform.service
  sudo systemctl --no-pager --full status test-platform.service
else
  echo "Restarting BusyBox init service..."
  sudo /etc/init.d/S99test-platform stop || true
  sudo /etc/init.d/S99test-platform start
fi

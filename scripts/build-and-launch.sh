#!/usr/bin/env bash
# Build the native board service and Qt client, then launch the client on the
# board display. Run on the ARM64 board: sudo bash scripts/build-and-launch.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOARDD_DIR="$ROOT_DIR/boardd"
QT_DIR="$ROOT_DIR/qt-client"
SOCKET_PATH="${BOARDD_SOCKET:-/run/boardd/boardd.sock}"
LOG_PATH="${BOARDD_LOG:-/var/log/boardd.log}"

if [[ "${EUID}" -ne 0 ]]; then
  exec sudo --preserve-env=BOARDD_SOCKET,BOARDD_LOG "$0" "$@"
fi

command -v go >/dev/null || { echo "Missing Go compiler." >&2; exit 1; }
command -v cmake >/dev/null || { echo "Missing CMake." >&2; exit 1; }

echo "Building boardd..."
(
  cd "$BOARDD_DIR"
  CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o boardd .
)

echo "Building Qt client..."
cmake -S "$QT_DIR" -B "$QT_DIR/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$QT_DIR/build" -j"$(nproc)"

if [[ ! -S "$SOCKET_PATH" ]]; then
  echo "Starting boardd at $SOCKET_PATH..."
  mkdir -p "$(dirname "$SOCKET_PATH")" "$(dirname "$LOG_PATH")"
  BOARDD_SOCKET="$SOCKET_PATH" "$BOARDD_DIR/boardd" >>"$LOG_PATH" 2>&1 &
  BOARDD_PID=$!
  sleep 1
  if ! kill -0 "$BOARDD_PID" 2>/dev/null || [[ ! -S "$SOCKET_PATH" ]]; then
    echo "boardd did not start. See $LOG_PATH" >&2
    exit 1
  fi
else
  echo "Using existing boardd socket: $SOCKET_PATH"
fi

# The board image provides display plugins and QML runtime in this location.
if [[ -f /usr/helperboard/qt_env.sh ]]; then
  # shellcheck disable=SC1091
  source /usr/helperboard/qt_env.sh
fi

export BOARDD_SOCKET="$SOCKET_PATH"
export BOARDD_QML_PATH="$QT_DIR/qml/Main.qml"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-eglfs}"
export QT_QPA_EGLFS_INTEGRATION="${QT_QPA_EGLFS_INTEGRATION:-none}"

echo "Launching Qt client on $QT_QPA_PLATFORM..."
exec "$QT_DIR/build/boardd-qml-client"

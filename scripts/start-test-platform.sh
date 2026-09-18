#!/usr/bin/env bash
# Starts already-built boardd and the Qt test application. Intended for boot.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOARDD_BIN="$ROOT_DIR/boardd/boardd"
QT_BIN="$ROOT_DIR/qt-client/build/boardd-qml-client"
SOCKET_PATH="${BOARDD_SOCKET:-/run/boardd/boardd.sock}"
LOG_PATH="${BOARDD_LOG:-/var/log/boardd.log}"

[[ -x "$BOARDD_BIN" ]] || { echo "Missing boardd: $BOARDD_BIN" >&2; exit 1; }
[[ -x "$QT_BIN" ]] || { echo "Missing Qt client: $QT_BIN. Build it first." >&2; exit 1; }

if [[ ! -S "$SOCKET_PATH" ]]; then
  mkdir -p "$(dirname "$SOCKET_PATH")" "$(dirname "$LOG_PATH")"
  BOARDD_SOCKET="$SOCKET_PATH" "$BOARDD_BIN" >>"$LOG_PATH" 2>&1 &
fi

# Load the board vendor's display/QML environment when present.
if [[ -f /usr/helperboard/qt_env.sh ]]; then
  set +u
  source /usr/helperboard/qt_env.sh
  set -u
fi

export BOARDD_SOCKET="$SOCKET_PATH"
export BOARDD_QML_PATH="$ROOT_DIR/qt-client/qml/Main.qml"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-eglfs}"
export QT_QPA_EGLFS_INTEGRATION="${QT_QPA_EGLFS_INTEGRATION:-none}"
export QT_QPA_EGLFS_NO_LIBINPUT="${QT_QPA_EGLFS_NO_LIBINPUT:-1}"

exec "$QT_BIN"

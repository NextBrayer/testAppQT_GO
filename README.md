# Board Platform

Reusable ARM64 board platform, independent of Electron or any product UI.

```text
qt-client ── Unix-domain JSON IPC ──> /run/boardd/boardd.sock ──> boardd
```

## Contents

- `boardd/` — Go service that owns board/system access.
- `qt-client/` — minimal 1024x600 Qt 5/QML native test client.

`boardd` currently provides health, battery, network, USB, GPIO, Wi-Fi, and
power methods. See each component's README for its build and runtime details.

The Qt client is deployed with `qml/Main.qml` as a normal file. On the board,
start it with `BOARDD_QML_PATH` set to that file's installed location.

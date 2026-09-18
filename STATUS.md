# Implementation Status

Last updated: 2026-09-17

## Architecture

- `boardd/` is the OS-level Go service.
- Native IPC: newline-delimited JSON over `/run/boardd/boardd.sock`.
- `qt-client/` is a 1024x600 Qt 5/QML native client.
- Electron is not part of the new platform; the original Electron repository is
  retained only as the migration reference.

## Implemented `boardd` methods

```text
health.get
battery.get
network.status
usb.devices
gpio.read
gpio.write
wifi.status
wifi.scan
wifi.connect
wifi.enable
wifi.disable
power.suspend
power.reboot
power.poweroff
```

`battery.get` reads the board's `axp803-battery` uevent information and returns
human-unit values plus the raw kernel properties. GPIO uses `gpio-test.64`.
Wi-Fi uses `wpa_cli`/`wpa_supplicant`, BusyBox `ip`, and `udhcpc`.

## Verified board facts

- Board host name: `JawadDEVBOARD`.
- Native service socket and `health.get` work.
- `network.status` reported `wlan0` with `192.168.10.100/24`.
- Battery sysfs source: `/sys/class/power_supply/axp803-battery/uevent`.
- USB sysfs source: `/sys/bus/usb/devices`; board USB includes Goodix touchscreen
  and Terminus hub.
- Socket access for user `nextronic` was temporarily granted through an ACL.

## Qt client status

- Qt client compiles with the system Qt/CMake toolchain.
- Board display uses the older `/usr/helperboard/qt` runtime; it has no qmake or
  development SDK.
- The client was adjusted to avoid newer Qt JSON and `QLocalSocket` symbols so
  it can be tested with the helperboard runtime.
- QML is loaded from a normal file using `BOARDD_QML_PATH`, not a qrc resource.
- Use the helperboard EGLFS environment to target the physical screen.
- The board currently emits repeated malformed touchscreen press events under
  EGLFS (`TouchPointPressed without previous release event`), which can crash
  the old helperboard Qt runtime. This is an input/tslib configuration issue,
  not a native IPC failure.

## Remaining migration work

```text
I2C
UART and GPS streams
Quectel AT/URC service and 4G/PPP
Ethernet DHCP/static IP and AP mode
camera
speaker/audio and brightness
RTC/time/NTP
CPU/RAM/storage/thermal monitoring
touch calibration
test-state persistence, PDF generation, FTP upload
BusyBox init deployment and permanent socket group permissions
```

## Important runtime commands

Build `boardd` on the ARM64 board:

```sh
cd board-platform/boardd
CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o boardd .
```

Test native IPC:

```sh
printf '{"id":1,"method":"health.get"}\n' | \
  sudo socat - UNIX-CONNECT:/run/boardd/boardd.sock
```

Run the Qt client from its source directory:

```sh
source /usr/helperboard/qt_env.sh
BOARDD_QML_PATH=/home/nextronic/board-platform/qt-client/qml/Main.qml \
QT_QPA_PLATFORM=eglfs QT_QPA_EGLFS_INTEGRATION=none \
./build/boardd-qml-client
```

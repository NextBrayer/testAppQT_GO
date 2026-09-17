# boardd

`boardd` is the OS-level API for the ARM64 board. It deliberately has no
Electron, UI, TCP listener, or HTTP protocol. Its native Linux IPC endpoint is:

```text
/run/boardd/boardd.sock
```

Example response on Linux:

```json
{"id":1,"ok":true,"result":{"status":"ok","service":"boardd","version":"0.1.0","hostname":"a133","uptimeSeconds":93784,"uptime":"1d 02h 03m 04s"}}
```

Build a static ARM64 Linux binary on a Linux build host:

```sh
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags='-s -w' -o boardd .
```

Run it on the board:

```sh
./boardd
printf '{"id":1,"method":"health.get"}\n' | \
  socat - UNIX-CONNECT:/run/boardd/boardd.sock
```

The service reads uptime from `/proc/uptime`, so the health request should be
tested on the Linux board, not Windows.

Each request and response is exactly one JSON object terminated by a newline.
The client may keep the socket open and send additional requests. Example
request:

```json
{"id":1,"method":"health.get"}
```

Available read-only methods:

```text
health.get       Linux uptime and service identity
battery.get      Battery power_supply data
network.status   Interface status, MAC addresses, and assigned addresses
usb.devices      Physical USB devices from Linux sysfs
gpio.read         Read GPIO: params `{ "port": "h", "pin": 4 }`
gpio.write        Write GPIO: params `{ "port": "h", "pin": 4, "value": 1 }`
wifi.status       Wi-Fi radio, connection, and IPv4 status (`wpa_cli`)
wifi.scan         Scan Wi-Fi SSIDs (`wpa_cli`)
wifi.connect      Connect: params `{ "ssid": "Lab", "password": "..." }`
wifi.enable       Enable the Wi-Fi interface (`ip link`)
wifi.disable      Disable the Wi-Fi interface (`ip link`)
power.suspend     Suspend: params `{ "confirm": true }`
power.reboot      Reboot: params `{ "confirm": true }`
power.poweroff    Shut down: params `{ "confirm": true }`
```

For example, replace `health.get` in the `socat` command with `battery.get`,
`network.status`, or `usb.devices`.

## BusyBox Wi-Fi requirements

The Wi-Fi methods use `wpa_supplicant` and its `wpa_cli` control socket, plus
BusyBox `udhcpc` to obtain an IPv4 lease. Start `wpa_supplicant` for `wlan0`
before starting `boardd`; set `BOARDD_WIFI_INTERFACE` if the interface has a
different name. `wifi.connect` creates a runtime network in wpa_supplicant.

Use `BOARDD_SOCKET` only when an image uses a different runtime directory:

```sh
BOARDD_SOCKET=/tmp/boardd.sock ./boardd
```

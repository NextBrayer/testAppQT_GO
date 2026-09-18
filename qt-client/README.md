# boardd QML client

Minimal 1024x600 Qt 5/QML test application for the native `boardd` Unix
socket. It does not use HTTP, Electron, or a web browser.

## Dependencies on the board

Install Qt 5 development packages with Quick, QML, and Network modules, plus
CMake and a C++ compiler. The app needs permission to access:

```text
/run/boardd/boardd.sock
```

For initial testing, run the app as root. For production, place the UI user in
the socket's group instead of running the UI as root.

## Build

Use the board's own Qt SDK for the executable that will run on its display.
The qmake route prevents a binary compiled against Ubuntu's system Qt from
loading the older `/usr/helperboard/qt` libraries at runtime:

```sh
source /usr/helperboard/qt_env.sh
cd clients/boardd-qml
$QTDIR/bin/qmake boardd-qml-client.pro -o Makefile
make -j2
./boardd-qml-client
```

The CMake route is suitable only when it resolves the same Qt installation:

```sh
cd clients/boardd-qml
source /usr/helperboard/qt_env.sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$QTDIR"
cmake --build build -j"$(nproc)"
./build/boardd-qml-client
```

The UI sends direct JSON requests to `boardd`, including health, battery,
network, USB, Wi-Fi status/scan, and GPIO PB4 read/write.

`Main.qml` is deployed as a normal file rather than a Qt resource. Set
`BOARDD_QML_PATH` when it is not located at `../qml/Main.qml` relative to the
executable.

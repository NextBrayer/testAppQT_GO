import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import BoarddClient 1.0

ApplicationWindow {
    id: window
    width: 1024; height: 600
    minimumWidth: width; maximumWidth: width
    minimumHeight: height; maximumHeight: height
    visible: true
    title: "Board Platform"
    color: "#08111f"

    property bool busy: false
    property bool responseOK: true
    property string responseTitle: "Board service ready"
    property string responseText: "Choose a board category."
    property string page: "home" // home, category, wifi
    property string selectedCategory: ""
    property string pendingMethod: ""
    property var pendingParams: ({})
    property string pendingLabel: ""
    property string currentTime: Qt.formatTime(new Date(), "hh:mm")

    property var categories: [
        { name: "Overview", color: "#458ed0", icon: "icons/overview.svg" },
        { name: "Connectivity", color: "#36a798", icon: "icons/connectivity.svg" },
        { name: "Hardware", color: "#d59a4a", icon: "icons/hardware.svg" },
        { name: "System", color: "#c86a75", icon: "icons/system.svg" }
    ]

    property var categoryActions: ({
        "Overview": [
            { label: "System health", detail: "Service and uptime", method: "health.get", accent: "#1976d2" },
            { label: "Battery", detail: "Power supply values", method: "battery.get", accent: "#7956cf" },
            { label: "Network", detail: "All interfaces", method: "network.status", accent: "#1976d2" },
            { label: "USB devices", detail: "Connected USB", method: "usb.devices", accent: "#1976d2" }
        ],
        "Connectivity": [
            { label: "Wi-Fi", detail: "Status, scan and connect", page: "wifi", accent: "#008b82", icon: "icons/connectivity.svg" },
            { label: "4G modem", detail: "Reserved for modem service", accent: "#66798e", available: false, icon: "icons/connectivity.svg" },
            { label: "Ethernet", detail: "Reserved for Ethernet service", accent: "#66798e", available: false, icon: "icons/link.svg" }
        ],
        "Hardware": [
            { label: "Read PB4", detail: "GPIO input", method: "gpio.read", params: { port: "b", pin: 4 }, accent: "#d48620" },
            { label: "Set PB4 high", detail: "GPIO output", method: "gpio.write", params: { port: "b", pin: 4, value: 1 }, accent: "#c65252", confirm: true },
            { label: "I2C bus", detail: "Reserved for I2C service", accent: "#66798e", available: false },
            { label: "UART ports", detail: "Reserved for UART service", accent: "#66798e", available: false },
            { label: "Touch panel", detail: "Reserved for touch service", accent: "#66798e", available: false },
            { label: "Camera", detail: "Reserved for camera service", accent: "#66798e", available: false }
        ],
        "System": [
            { label: "Reboot", detail: "Restart the board", method: "power.reboot", params: { confirm: true }, accent: "#a54b4b", confirm: true },
            { label: "Power off", detail: "Shut down the board", method: "power.poweroff", params: { confirm: true }, accent: "#813346", confirm: true }
        ]
    })

    Timer { interval: 1000; running: true; repeat: true; onTriggered: window.currentTime = Qt.formatTime(new Date(), "hh:mm") }

    function callBoardd(method, params, label) {
        if (busy) return
        busy = true
        responseOK = true
        responseTitle = label || method
        responseText = "Sending request..."
        board.request(method, params || {})
    }
    function openCategory(name) { selectedCategory = name; page = "category" }
    function goHome() { page = "home"; selectedCategory = "" }
    function showUnavailable(label) {
        responseOK = false
        responseTitle = label
        responseText = "The UI is ready for this service, but the matching boardd method has not been implemented yet."
    }
    function confirmAction(method, params, label) {
        pendingMethod = method; pendingParams = params; pendingLabel = label
        confirmDialog.open()
    }

    BoardClient {
        id: board
        onResponseReceived: function(id, method, ok, resultText, error) {
            window.busy = false
            window.responseOK = ok
            window.responseTitle = (ok ? "Completed: " : "Failed: ") + method
            window.responseText = ok ? resultText : "Error: " + error
        }
    }

    Dialog {
        id: confirmDialog
        modal: true; focus: true; width: 430
        x: (window.width - width) / 2; y: (window.height - height) / 2
        title: "Confirm hardware action"
        standardButtons: Dialog.Cancel | Dialog.Ok
        background: Rectangle { radius: 14; color: "#17263d"; border.color: "#5077a8" }
        header: Label { text: confirmDialog.title; color: "white"; font.pixelSize: 21; font.bold: true; padding: 20 }
        contentItem: Label { text: "Run '" + window.pendingLabel + "'?\n\nThis command changes board hardware or system state."; color: "#d7e7fa"; font.pixelSize: 16; wrapMode: Text.WordWrap; padding: 20 }
        onAccepted: window.callBoardd(window.pendingMethod, window.pendingParams, window.pendingLabel)
    }

    Dialog {
        id: wifiDialog
        modal: true; focus: true; width: 470
        x: (window.width - width) / 2; y: (window.height - height) / 2
        title: "Connect Wi-Fi"
        standardButtons: Dialog.Cancel | Dialog.Ok
        background: Rectangle { radius: 14; color: "#17263d"; border.color: "#2e9c91" }
        header: Label { text: wifiDialog.title; color: "white"; font.pixelSize: 21; font.bold: true; padding: 20 }
        contentItem: ColumnLayout {
            spacing: 10
            Label { text: "Enter the access point details"; color: "#b8d9d5"; font.pixelSize: 14 }
            TextField {
                id: ssidInput; Layout.fillWidth: true; placeholderText: "Wi-Fi name (SSID)"; focus: true
                color: "white"; selectByMouse: true
                background: Rectangle { radius: 8; color: "#0a1726"; border.color: ssidInput.activeFocus ? "#31b6a8" : "#47657f" }
                onActiveFocusChanged: if (activeFocus) Qt.inputMethod.show()
            }
            TextField {
                id: passwordInput; Layout.fillWidth: true; placeholderText: "Password (empty for open network)"; echoMode: TextInput.Password
                color: "white"; selectByMouse: true
                background: Rectangle { radius: 8; color: "#0a1726"; border.color: passwordInput.activeFocus ? "#31b6a8" : "#47657f" }
                onActiveFocusChanged: if (activeFocus) Qt.inputMethod.show()
            }
            Label { text: "Use a USB keyboard, or the platform virtual keyboard when installed."; color: "#8fa9c2"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        }
        onOpened: { ssidInput.forceActiveFocus(); Qt.inputMethod.show() }
        onAccepted: {
            if (ssidInput.text.length === 0) { responseOK = false; responseTitle = "Wi-Fi"; responseText = "SSID is required."; return }
            window.callBoardd("wifi.connect", { ssid: ssidInput.text, password: passwordInput.text }, "Connect Wi-Fi")
            ssidInput.text = ""; passwordInput.text = ""
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 18; spacing: 14
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 70; radius: 14
            color: "#122741"; border.color: "#2d527d"; border.width: 1
            RowLayout {
                anchors.fill: parent; anchors.margins: 15; spacing: 14
                Button {
                    visible: window.page !== "home"; enabled: !window.busy; text: "Back"; font.bold: true
                    background: Rectangle { radius: 8; color: "#203952"; border.color: "#477496" }
                    contentItem: Text { text: parent.text; color: "white"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: window.page === "wifi" ? window.page = "category" : window.goHome()
                }
                ColumnLayout { Layout.fillWidth: true; spacing: 0
                    Label { text: "Board Platform"; color: "#f5f9ff"; font.pixelSize: 26; font.bold: true }
                    Label { text: board.socketPath; color: "#9ac0e8"; font.pixelSize: 13 }
                }
                Label { text: window.currentTime; color: "#f5f9ff"; font.pixelSize: 25; font.bold: true }
                Rectangle { Layout.preferredWidth: 112; Layout.preferredHeight: 34; radius: 17; color: window.busy ? "#70501b" : "#12533b"
                    Label { anchors.centerIn: parent; text: window.busy ? "WORKING" : "CONNECTED"; color: "white"; font.pixelSize: 12; font.bold: true }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: window.page === "home" ? 0 : (window.page === "category" ? 1 : 2)

            Item {
                ColumnLayout { anchors.fill: parent; spacing: 12
                    Label { text: "Services"; color: "#f5f9ff"; font.pixelSize: 26; font.bold: true }
                    Label { text: "Choose a category"; color: "#92abc8"; font.pixelSize: 15 }
                    GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; columnSpacing: 12; rowSpacing: 12
                    Repeater { model: window.categories
                        delegate: Button {
                            id: categoryButton
                            Layout.fillWidth: true; Layout.fillHeight: true; text: modelData.name; font.pixelSize: 26; font.bold: true
                            background: Rectangle {
                                radius: 12; color: categoryButton.down ? "#1b3857" : "#122741"
                                border.color: modelData.color; border.width: 2
                                Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 8; radius: 4; color: modelData.color }
                            }
                            contentItem: Row {
                                anchors.centerIn: parent; spacing: 16
                                Image { width: 42; height: 42; source: modelData.icon; fillMode: Image.PreserveAspectFit }
                                Text { text: categoryButton.text; color: "white"; font: categoryButton.font; verticalAlignment: Text.AlignVCenter }
                            }
                            onClicked: window.openCategory(modelData.name)
                        }
                    }
                }
                }
            }

            Item {
                RowLayout { anchors.fill: parent; spacing: 14
                    Rectangle { Layout.preferredWidth: 500; Layout.fillHeight: true; radius: 14; color: "#101f34"; border.color: "#294a70"
                        ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 10
                            Label { text: window.selectedCategory; color: "white"; font.pixelSize: 28; font.bold: true }
                            Label { text: "Select a service"; color: "#92abc8"; font.pixelSize: 15 }
                            GridLayout { Layout.fillWidth: true; columns: 1; columnSpacing: 10; rowSpacing: 10
                                Repeater { model: window.categoryActions[window.selectedCategory]
                                    delegate: ActionButton { text: modelData.label; detail: modelData.detail || ""; iconSource: modelData.icon || ""; accent: modelData.accent || "#1976d2"; enabled: !window.busy && modelData.available !== false
                                        onTriggered: {
                                            if (modelData.page === "wifi") window.page = "wifi"
                                            else if (modelData.confirm === true) window.confirmAction(modelData.method, modelData.params || {}, modelData.label)
                                            else window.callBoardd(modelData.method, modelData.params || {}, modelData.label)
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }
                    Loader { Layout.fillWidth: true; Layout.fillHeight: true; sourceComponent: responsePanel }
                }
            }

            Item {
                RowLayout { anchors.fill: parent; spacing: 14
                    Rectangle { Layout.preferredWidth: 500; Layout.fillHeight: true; radius: 14; color: "#101f34"; border.color: "#2d756e"
                        ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 12
                            Label { text: "Wi-Fi"; color: "white"; font.pixelSize: 28; font.bold: true }
                            Label { text: "Manage the wlan0 connection through boardd"; color: "#92c8c2"; font.pixelSize: 14 }
                            ActionButton { text: "Status"; detail: "Current Wi-Fi link and IP"; iconSource: "icons/connectivity.svg"; accent: "#008b82"; enabled: !window.busy; onTriggered: window.callBoardd("wifi.status", {}, text) }
                            ActionButton { text: "Scan networks"; detail: "Find nearby access points"; iconSource: "icons/search.svg"; accent: "#008b82"; enabled: !window.busy; onTriggered: window.callBoardd("wifi.scan", {}, text) }
                            ActionButton { text: "Connect"; detail: "Enter Wi-Fi name and password"; iconSource: "icons/link.svg"; accent: "#1976d2"; enabled: !window.busy; onTriggered: wifiDialog.open() }
                            ActionButton { text: "Disconnect"; detail: "Leave the current network"; iconSource: "icons/link.svg"; accent: "#b36b3b"; enabled: !window.busy; onTriggered: window.callBoardd("wifi.disconnect", {}, text) }
                            RowLayout { Layout.fillWidth: true; spacing: 10
                                ActionButton { Layout.fillWidth: true; text: "Enable radio"; accent: "#3b8c75"; enabled: !window.busy; onTriggered: window.callBoardd("wifi.enable", {}, text) }
                                ActionButton { Layout.fillWidth: true; text: "Disable radio"; accent: "#7e4654"; enabled: !window.busy; onTriggered: window.callBoardd("wifi.disable", {}, text) }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }
                    Loader { Layout.fillWidth: true; Layout.fillHeight: true; sourceComponent: responsePanel }
                }
            }
        }
    }

    Component {
        id: responsePanel
        Rectangle {
        radius: 14; color: "#0c1829"; border.color: window.responseOK ? "#315777" : "#944e58"; border.width: 1
        ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 12
            RowLayout { Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: window.responseTitle; color: window.responseOK ? "#9bd6ff" : "#ffb1b8"; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight }
                BusyIndicator { running: window.busy; visible: running; Layout.preferredWidth: 28; Layout.preferredHeight: 28 }
            }
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: 10; color: "#07101c"; border.color: "#1d3650"; clip: true
                Flickable { anchors.fill: parent; anchors.margins: 14; contentWidth: width; contentHeight: output.paintedHeight; clip: true
                    Text { id: output; width: parent.width; text: window.responseText; color: "#d8e8fa"; font.family: "monospace"; font.pixelSize: 15; wrapMode: Text.WrapAnywhere }
                }
            }
        }
    }
    }
}

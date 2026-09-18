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
    color: "#f3f6fa"

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
        background: Rectangle { radius: 14; color: "white"; border.color: "#d7e1ed" }
        header: Label { text: confirmDialog.title; color: "#17243a"; font.pixelSize: 21; font.bold: true; padding: 20 }
        contentItem: Label { text: "Run '" + window.pendingLabel + "'?\n\nThis command changes board hardware or system state."; color: "#53657a"; font.pixelSize: 16; wrapMode: Text.WordWrap; padding: 20 }
        onAccepted: window.callBoardd(window.pendingMethod, window.pendingParams, window.pendingLabel)
    }

    Dialog {
        id: wifiDialog
        modal: true; focus: true; width: 470
        x: (window.width - width) / 2; y: (window.height - height) / 2
        title: "Connect Wi-Fi"
        standardButtons: Dialog.Cancel | Dialog.Ok
        background: Rectangle { radius: 14; color: "white"; border.color: "#cde0eb" }
        header: Label { text: wifiDialog.title; color: "#17243a"; font.pixelSize: 21; font.bold: true; padding: 20 }
        contentItem: ColumnLayout {
            spacing: 10
            Label { text: "Enter the access point details"; color: "#53657a"; font.pixelSize: 14 }
            TextField {
                id: ssidInput; Layout.fillWidth: true; placeholderText: "Wi-Fi name (SSID)"; focus: true
                color: "#17243a"; selectByMouse: true
                background: Rectangle { radius: 8; color: "#f8fafc"; border.color: ssidInput.activeFocus ? "#246bdb" : "#cfd9e5" }
                onActiveFocusChanged: if (activeFocus) Qt.inputMethod.show()
            }
            TextField {
                id: passwordInput; Layout.fillWidth: true; placeholderText: "Password (empty for open network)"; echoMode: TextInput.Password
                color: "#17243a"; selectByMouse: true
                background: Rectangle { radius: 8; color: "#f8fafc"; border.color: passwordInput.activeFocus ? "#246bdb" : "#cfd9e5" }
                onActiveFocusChanged: if (activeFocus) Qt.inputMethod.show()
            }
            Label { text: "Use a USB keyboard, or the platform virtual keyboard when installed."; color: "#708096"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
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
            color: "#ffffff"; border.color: "#dce4ee"; border.width: 1
            RowLayout {
                anchors.fill: parent; anchors.margins: 15; spacing: 14
                Button {
                    visible: window.page !== "home"; enabled: !window.busy; text: "Back"; font.bold: true
                    background: Rectangle { radius: 8; color: "#eef4fb"; border.color: "#cbd9e8" }
                    contentItem: Text { text: parent.text; color: "#246bdb"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: window.page === "wifi" ? window.page = "category" : window.goHome()
                }
                ColumnLayout { Layout.fillWidth: true; spacing: 0
                    Label { text: "Board Platform"; color: "#17243a"; font.pixelSize: 26; font.bold: true }
                    Label { text: "Device service console"; color: "#708096"; font.pixelSize: 13 }
                }
                Label { text: window.currentTime; color: "#17243a"; font.pixelSize: 25; font.bold: true }
                Rectangle { Layout.preferredWidth: 112; Layout.preferredHeight: 34; radius: 17; color: window.busy ? "#e49c35" : "#28a879"
                    Label { anchors.centerIn: parent; text: window.busy ? "WORKING" : "CONNECTED"; color: "white"; font.pixelSize: 12; font.bold: true }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: window.page === "home" ? 0 : (window.page === "category" ? 1 : 2)

            Item {
                ColumnLayout { anchors.fill: parent; spacing: 12
                    Label { text: "Services"; color: "#17243a"; font.pixelSize: 28; font.bold: true }
                    Label { text: "Choose a device service"; color: "#708096"; font.pixelSize: 15 }
                    GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; columnSpacing: 12; rowSpacing: 12
                    Repeater { model: window.categories
                        delegate: Button {
                            id: categoryButton
                            Layout.fillWidth: true; Layout.fillHeight: true; text: modelData.name; font.pixelSize: 26; font.bold: true
                            background: Rectangle {
                                radius: 14; color: categoryButton.down ? "#eef4fb" : "#ffffff"
                                border.color: categoryButton.hovered ? modelData.color : "#dbe3ed"; border.width: 1
                                Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 6; radius: 3; color: modelData.color }
                            }
                            contentItem: Row {
                                anchors.centerIn: parent; spacing: 16
                                Rectangle { width: 56; height: 56; radius: 28; color: modelData.color
                                    Image { anchors.centerIn: parent; width: 30; height: 30; source: modelData.icon; fillMode: Image.PreserveAspectFit }
                                }
                                Text { text: categoryButton.text; color: "#17243a"; font: categoryButton.font; verticalAlignment: Text.AlignVCenter }
                            }
                            onClicked: window.openCategory(modelData.name)
                        }
                    }
                }
                }
            }

            Item {
                RowLayout { anchors.fill: parent; spacing: 14
                    Rectangle { Layout.preferredWidth: 500; Layout.fillHeight: true; radius: 14; color: "#ffffff"; border.color: "#dbe3ed"
                        ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 10
                            Label { text: window.selectedCategory; color: "#17243a"; font.pixelSize: 28; font.bold: true }
                            Label { text: "Select a service"; color: "#708096"; font.pixelSize: 15 }
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
                    Rectangle { Layout.preferredWidth: 500; Layout.fillHeight: true; radius: 14; color: "#ffffff"; border.color: "#cde0eb"
                        ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 12
                            Label { text: "Wi-Fi"; color: "#17243a"; font.pixelSize: 28; font.bold: true }
                            Label { text: "Manage the wlan0 connection through boardd"; color: "#708096"; font.pixelSize: 14 }
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
        radius: 14; color: "#ffffff"; border.color: window.responseOK ? "#dbe3ed" : "#eaa4ab"; border.width: 1
        ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 12
            RowLayout { Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: window.responseTitle; color: window.responseOK ? "#246bdb" : "#c44d59"; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight }
                BusyIndicator { running: window.busy; visible: running; Layout.preferredWidth: 28; Layout.preferredHeight: 28 }
            }
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: 10; color: "#f6f8fb"; border.color: "#e2e8f0"; clip: true
                Flickable { anchors.fill: parent; anchors.margins: 14; contentWidth: width; contentHeight: output.paintedHeight; clip: true
                    Text { id: output; width: parent.width; text: window.responseText; color: "#34465c"; font.family: "monospace"; font.pixelSize: 15; wrapMode: Text.WrapAnywhere }
                }
            }
        }
    }
    }
}

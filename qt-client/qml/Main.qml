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
    color: "#f4f7fb"

    property bool busy: false
    property bool responseOK: true
    property string responseTitle: "Ready"
    property string responseText: "Choose a service to begin."
    property string detailsText: ""
    property string page: "home"
    property string selectedCategory: ""
    property string currentTime: Qt.formatTime(new Date(), "hh:mm")
    property string pendingMethod: ""
    property var pendingParams: ({})
    property string pendingLabel: ""
    property var wifiNetworks: []

    property var categories: [
        { name: "Overview", subtitle: "Board status", color: "#2f80ed", icon: "icons/overview.svg" },
        { name: "Connectivity", subtitle: "Wi-Fi, 4G, Ethernet", color: "#14a38b", icon: "icons/connectivity.svg" },
        { name: "Hardware", subtitle: "GPIO, I2C, UART", color: "#e49a35", icon: "icons/hardware.svg" },
        { name: "System", subtitle: "Power controls", color: "#c95d69", icon: "icons/system.svg" }
    ]

    property var categoryActions: ({
        "Overview": [
            { label: "System health", detail: "Uptime and service state", method: "health.get", accent: "#2f80ed", icon: "icons/overview.svg" },
            { label: "Battery", detail: "Charge and power values", method: "battery.get", accent: "#7956cf", icon: "icons/system.svg" },
            { label: "Network", detail: "Network interfaces", method: "network.status", accent: "#2f80ed", icon: "icons/link.svg" },
            { label: "USB devices", detail: "Connected peripherals", method: "usb.devices", accent: "#2f80ed", icon: "icons/hardware.svg" }
        ],
        "Connectivity": [
            { label: "Wi-Fi", detail: "Status, scan and connect", page: "wifi", accent: "#14a38b", icon: "icons/connectivity.svg" },
            { label: "4G modem", detail: "Coming soon", accent: "#aab5c2", available: false, icon: "icons/connectivity.svg" },
            { label: "Ethernet", detail: "Coming soon", accent: "#aab5c2", available: false, icon: "icons/link.svg" }
        ],
        "Hardware": [
            { label: "GPIO", detail: "Select port and pin", page: "gpio", accent: "#e49a35", icon: "icons/hardware.svg" },
            { label: "I2C bus", detail: "Coming soon", accent: "#aab5c2", available: false, icon: "icons/hardware.svg" },
            { label: "UART ports", detail: "Coming soon", accent: "#aab5c2", available: false, icon: "icons/hardware.svg" }
        ],
        "System": [
            { label: "Time and NTP", detail: "Clock, timezone and sync", page: "time", accent: "#2f80ed", icon: "icons/system.svg" },
            { label: "Reboot", detail: "Restart the board", method: "power.reboot", params: { confirm: true }, accent: "#c95d69", icon: "icons/system.svg", confirm: true },
            { label: "Power off", detail: "Shut down safely", method: "power.poweroff", params: { confirm: true }, accent: "#c95d69", icon: "icons/system.svg", confirm: true }
        ]
    })

    Timer { interval: 1000; running: true; repeat: true; onTriggered: window.currentTime = Qt.formatTime(new Date(), "hh:mm") }

    function callBoardd(method, params, label) {
        if (busy) return
        busy = true; responseOK = true
        responseTitle = label || method
        responseText = "Working..."
        detailsText = ""
        board.request(method, params || {})
    }
    function goHome() { page = "home"; selectedCategory = "" }
    function openCategory(name) { selectedCategory = name; page = "category" }
    function back() { page === "wifi" || page === "time" ? page = "category" : goHome() }
    function confirmAction(method, params, label) { pendingMethod = method; pendingParams = params; pendingLabel = label; confirmDialog.open() }
    function openWiFiConnect(ssid) {
        ssidInput.text = ssid || ""
        passwordInput.text = ""
        wifiDialog.open()
    }

    function summary(method, resultText) {
        try {
            var data = JSON.parse(resultText)
            if (method === "health.get") return "Service online - uptime " + (data.uptime || "unknown")
            if (method === "battery.get") return "Battery " + (data.capacityPercent === undefined ? "available" : data.capacityPercent + "%") + " - " + (data.state || "unknown")
            if (method === "usb.devices") return (data.length || 0) + " USB device(s) detected"
            if (method === "network.status") return (data.interfaces ? data.interfaces.length : 0) + " network interface(s) found"
            if (method === "wifi.status") return data.connection ? "Connected to " + data.connection : "Wi-Fi " + (data.state || "not connected")
            if (method === "wifi.scan") return (data.length || 0) + " Wi-Fi network(s) found"
            if (method === "wifi.connect") return data.connection ? "Connected to " + data.connection : "Wi-Fi connection updated"
            if (method === "wifi.disconnect") return "Wi-Fi disconnected"
            if (method === "wifi.enable") return "Wi-Fi radio enabled"
            if (method === "wifi.disable") return "Wi-Fi radio disabled"
            if (method === "gpio.read") return "P" + String(data.port || "").toUpperCase() + data.pin + " is " + (data.value === 1 ? "HIGH" : "LOW")
            if (method === "gpio.write") return "P" + String(data.port || "").toUpperCase() + data.pin + " set " + (data.value === 1 ? "HIGH" : "LOW")
            if (method === "time.status" || method === "time.set" || method === "time.ntp.sync") return (data.currentTime || "Time updated") + " - " + (data.timezone || "")
        } catch (error) { }
        return "Command completed"
    }

    BoardClient {
        id: board
        onResponseReceived: function(id, method, ok, resultText, error) {
            window.busy = false
            window.responseOK = ok
            window.responseTitle = ok ? "Completed" : "Action failed"
            window.detailsText = ok ? resultText : error
            window.responseText = ok ? window.summary(method, resultText) : error
            if (ok && method === "wifi.scan") {
                try {
                    window.wifiNetworks = JSON.parse(resultText)
                    if (window.wifiNetworks.length > 0)
                        wifiNetworkDialog.open()
                } catch (parseError) {
                    window.wifiNetworks = []
                }
            }
        }
    }

    Dialog {
        id: detailsDialog; modal: true; width: 820; height: 470
        x: (window.width - width) / 2; y: (window.height - height) / 2
        title: "Technical details"
        standardButtons: Dialog.Close
        background: Rectangle { radius: 14; color: "white"; border.color: "#d8e1eb" }
        header: Label { text: detailsDialog.title; color: "#17243a"; font.pixelSize: 21; font.bold: true; padding: 20 }
        contentItem: ScrollView {
            clip: true
            TextArea { text: window.detailsText; readOnly: true; selectByMouse: true; wrapMode: TextEdit.WrapAnywhere; color: "#34465c"; font.family: "monospace"; font.pixelSize: 14 }
        }
    }

    Dialog {
        id: confirmDialog; modal: true; width: 430
        x: (window.width - width) / 2; y: (window.height - height) / 2
        title: "Confirm action"; standardButtons: Dialog.Cancel | Dialog.Ok
        background: Rectangle { radius: 14; color: "white"; border.color: "#d8e1eb" }
        header: Label { text: confirmDialog.title; color: "#17243a"; font.pixelSize: 21; font.bold: true; padding: 20 }
        contentItem: Label { text: "Run '" + window.pendingLabel + "'?"; color: "#53657a"; font.pixelSize: 16; wrapMode: Text.WordWrap; padding: 20 }
        onAccepted: window.callBoardd(window.pendingMethod, window.pendingParams, window.pendingLabel)
    }

    Dialog {
        id: wifiDialog; modal: true; width: 470
        x: (window.width - width) / 2; y: (window.height - height) / 2
        title: "Connect Wi-Fi"; standardButtons: Dialog.Cancel | Dialog.Ok
        background: Rectangle { radius: 14; color: "white"; border.color: "#d8e1eb" }
        header: Label { text: wifiDialog.title; color: "#17243a"; font.pixelSize: 21; font.bold: true; padding: 20 }
        contentItem: ColumnLayout {
            spacing: 10
            TextField { id: ssidInput; Layout.fillWidth: true; placeholderText: "Wi-Fi name (SSID)"; focus: true; selectByMouse: true }
            TextField { id: passwordInput; Layout.fillWidth: true; placeholderText: "Password (leave empty for open network)"; echoMode: TextInput.Password; selectByMouse: true }
        }
        onOpened: { if (ssidInput.text.length === 0) ssidInput.forceActiveFocus(); else passwordInput.forceActiveFocus(); Qt.inputMethod.show() }
        onAccepted: {
            if (ssidInput.text.length === 0) { responseOK = false; responseTitle = "Action failed"; responseText = "SSID is required."; return }
            window.callBoardd("wifi.connect", { ssid: ssidInput.text, password: passwordInput.text }, "Connect Wi-Fi")
            ssidInput.text = ""; passwordInput.text = ""
        }
    }

    Dialog {
        id: wifiNetworkDialog; modal: true; width: 620; height: 430
        x: (window.width - width) / 2; y: (window.height - height) / 2
        title: "Select Wi-Fi network"; standardButtons: Dialog.Cancel
        background: Rectangle { radius: 14; color: "white"; border.color: "#d8e1eb" }
        header: Label { text: wifiNetworkDialog.title; color: "#17243a"; font.pixelSize: 21; font.bold: true; padding: 20 }
        contentItem: ListView {
            clip: true; model: window.wifiNetworks; spacing: 7
            delegate: Button {
                id: networkRow
                width: parent.width; height: 54; text: modelData; font.pixelSize: 16
                background: Rectangle { radius: 9; color: networkRow.down ? "#edf3ff" : "#f8fafc"; border.color: "#dbe3ed" }
                contentItem: Text { text: networkRow.text; color: "#17243a"; font: networkRow.font; leftPadding: 16; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                onClicked: { wifiNetworkDialog.close(); window.openWiFiConnect(modelData) }
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }

    Dialog {
        id: gpioDialog; modal: true; width: 480
        x: (window.width - width) / 2; y: (window.height - height) / 2
        title: "GPIO control"
        background: Rectangle { radius: 14; color: "white"; border.color: "#d8e1eb" }
        header: Label { text: gpioDialog.title; color: "#17243a"; font.pixelSize: 21; font.bold: true; padding: 20 }
        contentItem: ColumnLayout {
            spacing: 12
            Label { text: "Choose the GPIO to control"; color: "#708096"; font.pixelSize: 14 }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Port"; color: "#17243a"; font.pixelSize: 16 }
                ComboBox { id: gpioPort; Layout.fillWidth: true; model: ["A", "B", "C", "D", "E", "F", "G", "H"]; currentIndex: 1 }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Pin"; color: "#17243a"; font.pixelSize: 16 }
                SpinBox { id: gpioPin; Layout.fillWidth: true; from: 0; to: 31; value: 4; editable: true }
            }
        }
        footer: Rectangle {
            implicitHeight: 64; color: "transparent"
            RowLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 8
                Item { Layout.fillWidth: true }
                Button { text: "Cancel"; onClicked: gpioDialog.close() }
                Button { text: "Read"; onClicked: { gpioDialog.close(); window.callBoardd("gpio.read", { port: gpioPort.currentText, pin: gpioPin.value }, "Read P" + gpioPort.currentText + gpioPin.value) } }
                Button { text: "Set LOW"; onClicked: { gpioDialog.close(); window.confirmAction("gpio.write", { port: gpioPort.currentText, pin: gpioPin.value, value: 0 }, "Set P" + gpioPort.currentText + gpioPin.value + " LOW") } }
                Button { text: "Set HIGH"; onClicked: { gpioDialog.close(); window.confirmAction("gpio.write", { port: gpioPort.currentText, pin: gpioPin.value, value: 1 }, "Set P" + gpioPort.currentText + gpioPin.value + " HIGH") } }
            }
        }
    }

    Dialog {
        id: timeDialog; modal: true; width: 530
        x: (window.width - width) / 2; y: (window.height - height) / 2
        title: "Set date, time and timezone"; standardButtons: Dialog.Cancel | Dialog.Ok
        background: Rectangle { radius: 14; color: "white"; border.color: "#d8e1eb" }
        header: Label { text: timeDialog.title; color: "#17243a"; font.pixelSize: 20; font.bold: true; padding: 20 }
        contentItem: ColumnLayout {
            spacing: 10
            Label { text: "Date and time"; color: "#53657a" }
            TextField { id: dateTimeInput; Layout.fillWidth: true; placeholderText: "YYYY-MM-DD HH:MM:SS"; text: Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss") }
            Label { text: "Timezone"; color: "#53657a" }
            TextField { id: timezoneInput; Layout.fillWidth: true; placeholderText: "Example: Africa/Casablanca"; text: "Africa/Casablanca" }
        }
        onAccepted: window.callBoardd("time.set", { dateTime: dateTimeInput.text, timezone: timezoneInput.text }, "Set time")
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 18; spacing: 14
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 70; radius: 14; color: "white"; border.color: "#dce4ee"
            RowLayout {
                anchors.fill: parent; anchors.margins: 15; spacing: 14
                Button { visible: window.page !== "home"; text: "Back"; onClicked: window.back() }
                Label { Layout.fillWidth: true; text: "Board Platform"; color: "#17243a"; font.pixelSize: 26; font.bold: true }
                Label { text: window.currentTime; color: "#17243a"; font.pixelSize: 25; font.bold: true }
                Rectangle { Layout.preferredWidth: 110; Layout.preferredHeight: 32; radius: 16; color: window.busy ? "#e49a35" : "#22a06b"
                    Label { anchors.centerIn: parent; text: window.busy ? "WORKING" : "ONLINE"; color: "white"; font.pixelSize: 12; font.bold: true }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: window.page === "home" ? 0 : (window.page === "category" ? 1 : (window.page === "wifi" ? 2 : 3))
            Item {
                ColumnLayout { anchors.fill: parent; spacing: 12
                    Label { text: "Services"; color: "#17243a"; font.pixelSize: 30; font.bold: true }
                    Label { text: "Select a category"; color: "#708096"; font.pixelSize: 15 }
                    GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; columnSpacing: 12; rowSpacing: 12
                        Repeater { model: window.categories
                            delegate: Button {
                                id: categoryButton; Layout.fillWidth: true; Layout.fillHeight: true; text: modelData.name; font.pixelSize: 24; font.bold: true
                                background: Rectangle { radius: 16; color: categoryButton.down ? "#eef4fb" : "white"; border.color: "#dbe3ed"; border.width: 1 }
                                contentItem: Column { anchors.centerIn: parent; spacing: 11
                                    Rectangle { width: 58; height: 58; radius: 29; color: modelData.color; anchors.horizontalCenter: parent.horizontalCenter
                                        Image { anchors.centerIn: parent; source: modelData.icon; width: 30; height: 30 }
                                    }
                                    Text { text: categoryButton.text; color: "#17243a"; font: categoryButton.font; anchors.horizontalCenter: parent.horizontalCenter }
                                    Text { text: modelData.subtitle; color: "#708096"; font.pixelSize: 13; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                                onClicked: window.openCategory(modelData.name)
                            }
                        }
                    }
                }
            }

            Item {
                ColumnLayout { anchors.fill: parent; spacing: 12
                    Label { text: window.selectedCategory; color: "#17243a"; font.pixelSize: 29; font.bold: true }
                    Label { text: "Select an action"; color: "#708096"; font.pixelSize: 15 }
                    GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; columnSpacing: 12; rowSpacing: 12
                        Repeater { model: window.categoryActions[window.selectedCategory]
                            delegate: ActionButton { text: modelData.label; detail: modelData.detail || ""; iconSource: modelData.icon || ""; accent: modelData.accent || "#2f80ed"; enabled: !window.busy && modelData.available !== false
                                onTriggered: {
                                    if (modelData.page === "wifi") window.page = "wifi"
                                    else if (modelData.page === "gpio") gpioDialog.open()
                                    else if (modelData.page === "time") window.page = "time"
                                    else if (modelData.confirm) window.confirmAction(modelData.method, modelData.params || {}, modelData.label)
                                    else window.callBoardd(modelData.method, modelData.params || {}, modelData.label)
                                }
                            }
                        }
                    }
                    Loader { Layout.fillWidth: true; Layout.preferredHeight: 112; sourceComponent: responseSummary }
                }
            }

            Item {
                ColumnLayout { anchors.fill: parent; spacing: 12
                    Label { text: "Wi-Fi"; color: "#17243a"; font.pixelSize: 29; font.bold: true }
                    Label { text: "Manage the board wireless connection"; color: "#708096"; font.pixelSize: 15 }
                    GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; columnSpacing: 12; rowSpacing: 12
                        ActionButton { text: "Status"; detail: "Current link and IP address"; iconSource: "icons/connectivity.svg"; accent: "#14a38b"; enabled: !window.busy; onTriggered: window.callBoardd("wifi.status", {}, text) }
                        ActionButton { text: "Scan"; detail: "Find nearby Wi-Fi networks"; iconSource: "icons/search.svg"; accent: "#14a38b"; enabled: !window.busy; onTriggered: window.callBoardd("wifi.scan", {}, text) }
                        ActionButton { text: "Connect"; detail: "Enter Wi-Fi name and password"; iconSource: "icons/link.svg"; accent: "#2f80ed"; enabled: !window.busy; onTriggered: window.openWiFiConnect("") }
                        ActionButton { text: "Disconnect"; detail: "Leave the current network"; iconSource: "icons/link.svg"; accent: "#e49a35"; enabled: !window.busy; onTriggered: window.callBoardd("wifi.disconnect", {}, text) }
                        ActionButton { text: "Enable radio"; detail: "Turn on wlan0"; iconSource: "icons/connectivity.svg"; accent: "#14a38b"; enabled: !window.busy; onTriggered: window.callBoardd("wifi.enable", {}, text) }
                        ActionButton { text: "Disable radio"; detail: "Turn off wlan0"; iconSource: "icons/system.svg"; accent: "#c95d69"; enabled: !window.busy; onTriggered: window.callBoardd("wifi.disable", {}, text) }
                    }
                    Loader { Layout.fillWidth: true; Layout.preferredHeight: 112; sourceComponent: responseSummary }
                }
            }

            Item {
                ColumnLayout { anchors.fill: parent; spacing: 12
                    Label { text: "Time and NTP"; color: "#17243a"; font.pixelSize: 29; font.bold: true }
                    Label { text: "Configure the board clock and timezone"; color: "#708096"; font.pixelSize: 15 }
                    GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; columnSpacing: 12; rowSpacing: 12
                        ActionButton { text: "Time status"; detail: "Current board time and timezone"; iconSource: "icons/system.svg"; accent: "#2f80ed"; enabled: !window.busy; onTriggered: window.callBoardd("time.status", {}, text) }
                        ActionButton { text: "Set time"; detail: "Manual date, time and timezone"; iconSource: "icons/system.svg"; accent: "#2f80ed"; enabled: !window.busy; onTriggered: timeDialog.open() }
                        ActionButton { text: "Sync NTP"; detail: "Synchronize with pool.ntp.org"; iconSource: "icons/connectivity.svg"; accent: "#14a38b"; enabled: !window.busy; onTriggered: window.callBoardd("time.ntp.sync", {}, text) }
                    }
                    Loader { Layout.fillWidth: true; Layout.preferredHeight: 112; sourceComponent: responseSummary }
                }
            }
        }
    }

    Component {
        id: responseSummary
        Rectangle {
            radius: 14; color: "white"; border.color: window.responseOK ? "#dbe3ed" : "#efb6bc"; border.width: 1
            RowLayout { anchors.fill: parent; anchors.margins: 16; spacing: 14
                Rectangle { Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20; color: window.responseOK ? "#dff5e9" : "#fde7e9"
                    Text { anchors.centerIn: parent; text: window.responseOK ? "OK" : "!"; color: window.responseOK ? "#168652" : "#c44d59"; font.bold: true }
                }
                ColumnLayout { Layout.fillWidth: true; spacing: 2
                    Label { text: window.responseTitle; color: "#17243a"; font.pixelSize: 16; font.bold: true }
                    Label { Layout.fillWidth: true; text: window.responseText; color: "#607187"; font.pixelSize: 14; elide: Text.ElideRight }
                }
                Button { text: "Show details"; visible: window.detailsText.length > 0; onClicked: detailsDialog.open() }
            }
        }
    }
}

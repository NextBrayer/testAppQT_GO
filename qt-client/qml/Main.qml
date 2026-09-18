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
    property string responseText: "Select a diagnostic action."
    property string pendingMethod: ""
    property var pendingParams: ({})
    property string pendingLabel: ""
    property string selectedCategory: "Overview"
    property var categories: ["Overview", "Connectivity", "Hardware", "System"]

    // Extend this data only when a matching boardd method exists.
    property var actionGroups: ({
        "Overview": [
            { label: "System health", detail: "Service and uptime", method: "health.get", params: {}, accent: "#1976d2" },
            { label: "Battery", detail: "Power supply values", method: "battery.get", params: {}, accent: "#7956cf" },
            { label: "Network", detail: "All interfaces", method: "network.status", params: {}, accent: "#1976d2" },
            { label: "USB devices", detail: "Connected USB", method: "usb.devices", params: {}, accent: "#1976d2" }
        ],
        "Connectivity": [
            { label: "Wi-Fi status", detail: "Link and IP address", method: "wifi.status", params: {}, accent: "#008b82" },
            { label: "Wi-Fi scan", detail: "Nearby access points", method: "wifi.scan", params: {}, accent: "#008b82" },
            { label: "4G modem", detail: "Coming soon", accent: "#66798e", available: false },
            { label: "Ethernet", detail: "Coming soon", accent: "#66798e", available: false }
        ],
        "Hardware": [
            { label: "Read PB4", detail: "GPIO input", method: "gpio.read", params: { port: "b", pin: 4 }, accent: "#d48620" },
            { label: "Set PB4 high", detail: "GPIO output", method: "gpio.write", params: { port: "b", pin: 4, value: 1 }, accent: "#c65252", confirm: true },
            { label: "I2C bus", detail: "Coming soon", accent: "#66798e", available: false },
            { label: "UART ports", detail: "Coming soon", accent: "#66798e", available: false },
            { label: "Touch panel", detail: "Coming soon", accent: "#66798e", available: false },
            { label: "Camera", detail: "Coming soon", accent: "#66798e", available: false }
        ],
        "System": [
            { label: "Reboot", detail: "Restart the board", method: "power.reboot", params: { confirm: true }, accent: "#a54b4b", confirm: true },
            { label: "Power off", detail: "Shut down the board", method: "power.poweroff", params: { confirm: true }, accent: "#813346", confirm: true }
        ]
    })

    function callBoardd(method, params, label) {
        if (busy) return
        busy = true
        responseTitle = label || method
        responseText = "Sending request..."
        board.request(method, params || {})
    }
    function confirmAction(method, params, label) {
        pendingMethod = method; pendingParams = params; pendingLabel = label
        confirmDialog.open()
    }
    function showUnavailable(label) {
        responseOK = false
        responseTitle = label
        responseText = "This feature is reserved in the generic dashboard, but its boardd method is not implemented yet."
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
        contentItem: Label {
            text: "Run '" + window.pendingLabel + "'?\n\nThis command changes board hardware or system state."
            color: "#d7e7fa"; font.pixelSize: 16; wrapMode: Text.WordWrap; padding: 20
        }
        onAccepted: window.callBoardd(window.pendingMethod, window.pendingParams, window.pendingLabel)
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 18; spacing: 14
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 76; radius: 14
            color: "#122741"; border.color: "#2d527d"; border.width: 1
            RowLayout {
                anchors.fill: parent; anchors.margins: 17; spacing: 14
                Rectangle {
                    Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 21
                    color: window.busy ? "#f2a93b" : "#2bd58b"
                    Label { anchors.centerIn: parent; text: window.busy ? "..." : "OK"; color: "#062419"; font.pixelSize: 16; font.bold: true }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Label { text: "Board Platform"; color: "#f5f9ff"; font.pixelSize: 27; font.bold: true }
                    Label { text: board.socketPath; color: "#9ac0e8"; font.pixelSize: 14 }
                }
                Rectangle {
                    Layout.preferredWidth: 132; Layout.preferredHeight: 36; radius: 18
                    color: window.busy ? "#70501b" : "#12533b"
                    Label { anchors.centerIn: parent; text: window.busy ? "WORKING" : "CONNECTED"; color: "white"; font.pixelSize: 13; font.bold: true }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
            Rectangle {
                Layout.preferredWidth: 430; Layout.fillHeight: true; radius: 14
                color: "#101f34"; border.color: "#294a70"; border.width: 1
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 10
                    Label { text: window.selectedCategory; color: "white"; font.pixelSize: 20; font.bold: true }
                    Label { text: "Native boardd service actions"; color: "#92abc8"; font.pixelSize: 13 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 5
                        Repeater {
                            model: window.categories
                            delegate: Button {
                                Layout.fillWidth: true
                                text: modelData
                                font.pixelSize: 12; font.bold: true
                                enabled: !window.busy
                                background: Rectangle {
                                    radius: 7
                                    color: window.selectedCategory === modelData ? "#1976d2" : "#203952"
                                    border.color: window.selectedCategory === modelData ? "#6cafea" : "#365675"
                                }
                                contentItem: Text { text: parent.text; color: "white"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                                onClicked: window.selectedCategory = modelData
                            }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: 10; rowSpacing: 10
                        Repeater {
                            model: window.actionGroups[window.selectedCategory]
                            delegate: ActionButton {
                                text: modelData.label
                                detail: modelData.detail || ""
                                accent: modelData.accent || "#1976d2"
                                enabled: !window.busy && modelData.available !== false
                                onTriggered: {
                                    if (modelData.available === false)
                                        window.showUnavailable(modelData.label)
                                    else if (modelData.confirm === true)
                                        window.confirmAction(modelData.method, modelData.params || {}, modelData.label)
                                    else
                                        window.callBoardd(modelData.method, modelData.params || {}, modelData.label)
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 14
                color: "#0c1829"; border.color: window.responseOK ? "#315777" : "#944e58"; border.width: 1
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 18; spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        Label { Layout.fillWidth: true; text: window.responseTitle; color: window.responseOK ? "#9bd6ff" : "#ffb1b8"; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight }
                        BusyIndicator { running: window.busy; visible: running; Layout.preferredWidth: 28; Layout.preferredHeight: 28 }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 10; color: "#07101c"; border.color: "#1d3650"; border.width: 1; clip: true
                        Flickable {
                            anchors.fill: parent; anchors.margins: 14; contentWidth: width; contentHeight: output.paintedHeight; clip: true
                            Text { id: output; width: parent.width; text: window.responseText; color: "#d8e8fa"; font.family: "monospace"; font.pixelSize: 15; wrapMode: Text.WrapAnywhere }
                        }
                    }
                }
            }
        }
    }
}

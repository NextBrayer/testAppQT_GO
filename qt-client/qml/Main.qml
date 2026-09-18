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

    function callBoardd(method, params, label) {
        if (busy) return
        busy = true
        responseTitle = label || method
        responseText = "Sending request…"
        board.request(method, params || {})
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
            window.responseTitle = (ok ? "Completed · " : "Failed · ") + method
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
            text: "Run “" + window.pendingLabel + "”?\n\nThis command changes board hardware or system state."
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
                    Label { anchors.centerIn: parent; text: window.busy ? "…" : "✓"; color: "#062419"; font.pixelSize: 27; font.bold: true }
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
                    Label { text: "Quick diagnostics"; color: "white"; font.pixelSize: 20; font.bold: true }
                    Label { text: "Native boardd service commands"; color: "#92abc8"; font.pixelSize: 13 }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: 10; rowSpacing: 10
                        ActionButton { text: "System health"; accent: "#1976d2"; enabled: !window.busy; onTriggered: window.callBoardd("health.get", {}, text) }
                        ActionButton { text: "Battery"; accent: "#7956cf"; enabled: !window.busy; onTriggered: window.callBoardd("battery.get", {}, text) }
                        ActionButton { text: "Network"; accent: "#1976d2"; enabled: !window.busy; onTriggered: window.callBoardd("network.status", {}, text) }
                        ActionButton { text: "USB devices"; accent: "#1976d2"; enabled: !window.busy; onTriggered: window.callBoardd("usb.devices", {}, text) }
                        ActionButton { text: "Wi-Fi status"; accent: "#008b82"; enabled: !window.busy; onTriggered: window.callBoardd("wifi.status", {}, text) }
                        ActionButton { text: "Wi-Fi scan"; accent: "#008b82"; enabled: !window.busy; onTriggered: window.callBoardd("wifi.scan", {}, text) }
                        ActionButton { text: "Read PB4"; accent: "#d48620"; enabled: !window.busy; onTriggered: window.callBoardd("gpio.read", { port: "b", pin: 4 }, text) }
                        ActionButton { text: "Set PB4 high"; accent: "#c65252"; enabled: !window.busy; onTriggered: window.confirmAction("gpio.write", { port: "b", pin: 4, value: 1 }, text) }
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        ActionButton { Layout.fillWidth: true; text: "Reboot"; accent: "#a54b4b"; enabled: !window.busy; onTriggered: window.confirmAction("power.reboot", { confirm: true }, text) }
                        ActionButton { Layout.fillWidth: true; text: "Power off"; accent: "#813346"; enabled: !window.busy; onTriggered: window.confirmAction("power.poweroff", { confirm: true }, text) }
                    }
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

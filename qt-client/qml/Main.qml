import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import BoarddClient 1.0

ApplicationWindow {
    id: window
    width: 1024
    height: 600
    minimumWidth: 1024
    maximumWidth: 1024
    minimumHeight: 600
    maximumHeight: 600
    visible: true
    title: "Board Service Test"
    color: "#10151f"
    property bool busy: false
    property string activeMethod: ""

    function callBoardd(method, params) {
        if (busy)
            return
        busy = true
        activeMethod = method
        board.request(method, params || {})
    }

    BoardClient {
        id: board
        onResponseReceived: function(id, method, ok, result, error) {
            window.busy = false
            output.text = JSON.stringify({ id: id, method: method, ok: ok, result: result, error: error }, null, 2)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: 10
            color: "#192b42"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                ColumnLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Board Platform"
                        color: "white"
                        font.pixelSize: 27
                        font.bold: true
                    }
                    Label {
                        text: board.socketPath
                        color: "#a7c6ed"
                        font.pixelSize: 14
                    }
                }

                Rectangle {
                    radius: 12
                    color: window.busy ? "#a87615" : "#16744c"
                    Layout.preferredWidth: 116
                    Layout.preferredHeight: 32
                    Label {
                        anchors.centerIn: parent
                        text: window.busy ? "Working…" : "Ready"
                        color: "white"
                        font.bold: true
                    }
                }
            }
        }

        Label {
            text: "Native boardd commands"
            color: "white"
            font.pixelSize: 18
            font.bold: true
        }

        GridLayout {
            columns: 4
            columnSpacing: 12
            rowSpacing: 12

            Button { text: "Health"; enabled: !window.busy; onClicked: window.callBoardd("health.get") }
            Button { text: "Battery"; enabled: !window.busy; onClicked: window.callBoardd("battery.get") }
            Button { text: "Network"; enabled: !window.busy; onClicked: window.callBoardd("network.status") }
            Button { text: "USB devices"; enabled: !window.busy; onClicked: window.callBoardd("usb.devices") }
            Button { text: "Wi-Fi status"; enabled: !window.busy; onClicked: window.callBoardd("wifi.status") }
            Button { text: "Wi-Fi scan"; enabled: !window.busy; onClicked: window.callBoardd("wifi.scan") }
            Button { text: "Read PB4"; enabled: !window.busy; onClicked: window.callBoardd("gpio.read", { port: "b", pin: 4 }) }
            Button { text: "Set PB4 high"; enabled: !window.busy; onClicked: window.callBoardd("gpio.write", { port: "b", pin: 4, value: 1 }) }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#192230"
            radius: 8
            clip: true

            Text {
                id: output
                anchors.fill: parent
                anchors.margins: 14
                wrapMode: Text.WrapAnywhere
                text: "Choose a boardd request."
                color: "#d7e2f1"
                font.family: "monospace"
                font.pixelSize: 15
            }
        }
    }
}

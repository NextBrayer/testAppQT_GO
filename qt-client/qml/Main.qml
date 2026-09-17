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

    BoardClient {
        id: board
        onResponseReceived: function(id, method, ok, result, error) {
            output.text = JSON.stringify({ id: id, method: method, ok: ok, result: result, error: error }, null, 2)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Label {
            text: "boardd native IPC client"
            color: "white"
            font.pixelSize: 26
            font.bold: true
        }

        Label {
            text: board.socketPath
            color: "#9db2ce"
            font.pixelSize: 15
        }

        GridLayout {
            columns: 4
            columnSpacing: 12
            rowSpacing: 12

            Button { text: "Health"; onClicked: board.request("health.get") }
            Button { text: "Battery"; onClicked: board.request("battery.get") }
            Button { text: "Network"; onClicked: board.request("network.status") }
            Button { text: "USB devices"; onClicked: board.request("usb.devices") }
            Button { text: "Wi-Fi status"; onClicked: board.request("wifi.status") }
            Button { text: "Wi-Fi scan"; onClicked: board.request("wifi.scan") }
            Button { text: "Read PB4"; onClicked: board.request("gpio.read", { port: "b", pin: 4 }) }
            Button { text: "Write PB4 high"; onClicked: board.request("gpio.write", { port: "b", pin: 4, value: 1 }) }
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

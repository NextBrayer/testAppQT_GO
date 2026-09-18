import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Button {
    id: control
    property color accent: "#1976d2"
    property string detail: ""
    signal triggered()
    implicitHeight: detail.length > 0 ? 64 : 56
    Layout.fillWidth: true
    font.pixelSize: 16
    font.bold: true

    background: Rectangle {
        radius: 10
        color: !control.enabled ? "#263a52" : control.down ? Qt.darker(control.accent, 1.2) : control.accent
        border.width: 1
        border.color: !control.enabled ? "#3b516b" : Qt.lighter(control.accent, 1.18)
    }
    contentItem: Column {
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 2
        Text {
            width: parent.width; text: control.text; color: control.enabled ? "white" : "#a1b4c9"; font: control.font
            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
        }
        Text {
            visible: control.detail.length > 0; width: parent.width; text: control.detail
            color: control.enabled ? "#dcecff" : "#8296ad"; font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
        }
    }
    onClicked: triggered()
}

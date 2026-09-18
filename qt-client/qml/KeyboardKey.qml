import QtQuick 2.12
import QtQuick.Controls 2.12

Button {
    id: control
    font.pixelSize: 15
    font.bold: true
    background: Rectangle {
        radius: 7
        color: !control.enabled ? "#dbe3ed" : control.down ? "#cfe1fb" : "#ffffff"
        border.color: control.down ? "#4f8fe4" : "#c8d7e8"
        border.width: 1
    }
    contentItem: Text {
        text: control.text; color: "#24415f"; font: control.font
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}

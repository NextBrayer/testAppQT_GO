import QtQuick 2.12
import QtQuick.Controls 2.12

Button {
    id: control
    property color accent: "#246bdb"
    property bool outlined: false
    implicitHeight: 38
    font.pixelSize: 14
    font.bold: true

    background: Rectangle {
        radius: 9
        color: !control.enabled ? "#d9e1eb" : control.outlined ? (control.down ? "#e8f1ff" : "transparent") : (control.down ? Qt.darker(control.accent, 1.12) : control.accent)
        border.width: 1
        border.color: !control.enabled ? "#d9e1eb" : control.accent
    }
    contentItem: Text {
        text: control.text; font: control.font
        color: !control.enabled ? "#8795a6" : control.outlined ? control.accent : "white"
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
}

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Button {
    id: control
    property color accent: "#246bdb"
    property string detail: ""
    property string iconSource: ""
    signal triggered()

    implicitHeight: detail.length > 0 ? 76 : 62
    Layout.fillWidth: true
    font.pixelSize: 16
    font.bold: true

    background: Rectangle {
        radius: 12
        color: !control.enabled ? "#f1f4f8" : control.down ? "#edf3ff" : "#ffffff"
        border.width: 1
        border.color: !control.enabled ? "#d8e0ea" : control.hovered ? control.accent : "#dbe3ed"
    }
    contentItem: RowLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 12
        Rectangle {
            visible: control.iconSource.length > 0
            Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 21
            color: control.enabled ? control.accent : "#aebccc"
            Image { anchors.centerIn: parent; source: control.iconSource; width: 22; height: 22; fillMode: Image.PreserveAspectFit }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text { Layout.fillWidth: true; text: control.text; color: control.enabled ? "#17243a" : "#8491a2"; font: control.font; elide: Text.ElideRight }
            Text { visible: control.detail.length > 0; Layout.fillWidth: true; text: control.detail; color: control.enabled ? "#708096" : "#9aa5b4"; font.pixelSize: 12; elide: Text.ElideRight }
        }
        Text { visible: control.enabled; text: ">"; color: control.accent; font.pixelSize: 23; font.bold: true }
    }
    onClicked: triggered()
}

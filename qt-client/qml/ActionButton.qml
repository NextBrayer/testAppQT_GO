import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Button {
    id: control
    property color accent: "#1976d2"
    property string detail: ""
    property string iconSource: ""
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
    contentItem: RowLayout {
        anchors.fill: parent; anchors.margins: 10; spacing: 9
        Image { visible: control.iconSource.length > 0; source: control.iconSource; Layout.preferredWidth: 25; Layout.preferredHeight: 25; fillMode: Image.PreserveAspectFit }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 1
            Text { Layout.fillWidth: true; text: control.text; color: control.enabled ? "white" : "#a1b4c9"; font: control.font; elide: Text.ElideRight }
            Text { visible: control.detail.length > 0; Layout.fillWidth: true; text: control.detail; color: control.enabled ? "#dcecff" : "#8296ad"; font.pixelSize: 11; elide: Text.ElideRight }
        }
    }
    onClicked: triggered()
}

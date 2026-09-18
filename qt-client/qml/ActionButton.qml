import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Button {
    id: control
    property color accent: "#1976d2"
    property string detail: ""
    property string iconSource: ""
    signal triggered()
    implicitHeight: detail.length > 0 ? 72 : 60
    Layout.fillWidth: true
    font.pixelSize: 16
    font.bold: true

    background: Rectangle {
        radius: 12
        color: !control.enabled ? "#182536" : control.down ? "#1b3147" : "#14263a"
        border.width: 1
        border.color: !control.enabled ? "#263e56" : control.hovered ? Qt.lighter(control.accent, 1.25) : "#29465f"
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 4; radius: 2; color: control.enabled ? control.accent : "#465b70" }
    }
    contentItem: RowLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 11
        Rectangle {
            visible: control.iconSource.length > 0; Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
            color: control.enabled ? control.accent : "#3b5065"
            Image { anchors.centerIn: parent; source: control.iconSource; width: 21; height: 21; fillMode: Image.PreserveAspectFit }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 1
            Text { Layout.fillWidth: true; text: control.text; color: control.enabled ? "#f7fbff" : "#8496a9"; font: control.font; elide: Text.ElideRight }
            Text { visible: control.detail.length > 0; Layout.fillWidth: true; text: control.detail; color: control.enabled ? "#9cb1c8" : "#66798c"; font.pixelSize: 12; elide: Text.ElideRight }
        }
    }
    onClicked: triggered()
}

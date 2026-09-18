import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

Item {
    id: keyboard
    property var target: null
    property bool uppercase: false
    implicitHeight: 174
    implicitWidth: 430

    function type(value) {
        if (!target) return
        if (target.selectionStart !== target.selectionEnd)
            target.remove(target.selectionStart, target.selectionEnd - target.selectionStart)
        target.insert(target.cursorPosition, value)
    }
    function backspace() {
        if (!target) return
        if (target.selectionStart !== target.selectionEnd) {
            target.remove(target.selectionStart, target.selectionEnd - target.selectionStart)
        } else if (target.cursorPosition > 0) {
            target.remove(target.cursorPosition - 1, 1)
        }
    }

    Rectangle { anchors.fill: parent; radius: 12; color: "#eaf1f8"; border.color: "#d3dfeb" }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 8
        spacing: 5
        GridLayout {
            Layout.fillWidth: true; columns: 10; columnSpacing: 4; rowSpacing: 4
            Repeater {
                model: "1234567890".split("")
                delegate: KeyboardKey { Layout.fillWidth: true; text: keyboard.uppercase ? modelData.toUpperCase() : modelData; onClicked: { keyboard.type(text); keyboard.uppercase = false } }
            }
        }
        GridLayout {
            Layout.fillWidth: true; columns: 10; columnSpacing: 4; rowSpacing: 4
            Repeater {
                model: "qwertyuiop".split("")
                delegate: KeyboardKey { Layout.fillWidth: true; text: keyboard.uppercase ? modelData.toUpperCase() : modelData; onClicked: { keyboard.type(text); keyboard.uppercase = false } }
            }
        }
        GridLayout {
            Layout.fillWidth: true; columns: 9; columnSpacing: 4; rowSpacing: 4
            Repeater {
                model: "asdfghjkl".split("")
                delegate: KeyboardKey { Layout.fillWidth: true; text: keyboard.uppercase ? modelData.toUpperCase() : modelData; onClicked: { keyboard.type(text); keyboard.uppercase = false } }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 5
            KeyboardKey { Layout.preferredWidth: 48; text: "Shift"; onClicked: keyboard.uppercase = !keyboard.uppercase }
            KeyboardKey { Layout.preferredWidth: 32; text: "-"; onClicked: keyboard.type("-") }
            KeyboardKey { Layout.preferredWidth: 32; text: ":"; onClicked: keyboard.type(":") }
            KeyboardKey { Layout.preferredWidth: 32; text: "/"; onClicked: keyboard.type("/") }
            KeyboardKey { Layout.preferredWidth: 32; text: "."; onClicked: keyboard.type(".") }
            KeyboardKey { Layout.preferredWidth: 56; text: "Clear"; onClicked: if (keyboard.target) keyboard.target.text = "" }
            KeyboardKey { Layout.fillWidth: true; text: "Space"; onClicked: keyboard.type(" ") }
            KeyboardKey { Layout.preferredWidth: 90; text: "Backspace"; onClicked: keyboard.backspace() }
        }
    }
}

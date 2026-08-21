import QtQuick
import QtQuick.Controls

Item {
    id: root

    property string hotkeyText: "None"
    property int modifiers: 0
    property int vkCode: 0
    property bool isRecording: false

    signal hotkeyChanged(string text, int mods, int vk)

    implicitWidth: 200
    implicitHeight: 36

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: root.isRecording ? (Theme.isDark ? "#2a374a" : "#eff6ff") : Theme.bgInput
        border.color: root.isRecording ? Theme.borderFocus : (mouseArea.containsMouse ? Qt.darker(Theme.borderLight, 1.2) : Theme.borderLight)
        border.width: root.isRecording ? 1.5 : 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: root.isRecording ? (AppManager.isThai ? "กดปุ่มลัดที่ต้องการ..." : "Press hotkey...") : root.hotkeyText
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: root.isRecording ? Font.DemiBold : Font.Medium
                color: root.isRecording ? Theme.primary : Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.isRecording = true
                keyGrabber.forceActiveFocus()
            }
        }

        Item {
            id: keyGrabber
            focus: root.isRecording
            Keys.onPressed: function(event) {
                if (!root.isRecording) return;

                if (event.key === Qt.Key_Escape) {
                    root.isRecording = false;
                    event.accepted = true;
                    return;
                }

                // Collect modifiers
                let mods = 0;
                let parts = [];

                if (event.modifiers & Qt.ControlModifier) {
                    mods |= 0x0002; // MOD_CONTROL
                    parts.push("Ctrl");
                }
                if (event.modifiers & Qt.AltModifier) {
                    mods |= 0x0001; // MOD_ALT
                    parts.push("Alt");
                }
                if (event.modifiers & Qt.ShiftModifier) {
                    mods |= 0x0004; // MOD_SHIFT
                    parts.push("Shift");
                }
                if (event.modifiers & Qt.MetaModifier) {
                    mods |= 0x0008; // MOD_WIN
                    parts.push("Win");
                }

                // Check key
                let keyStr = "";
                let vk = event.nativeVirtualKey;

                if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) {
                    keyStr = String.fromCharCode(event.key);
                } else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                    keyStr = String.fromCharCode(event.key);
                } else if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F12) {
                    keyStr = "F" + (event.key - Qt.Key_F1 + 1);
                } else if (event.key === Qt.Key_Space) {
                    keyStr = "Space";
                } else if (event.key === Qt.Key_CapsLock) {
                    keyStr = "Caps Lock";
                } else if (event.key === Qt.Key_Tab) {
                    keyStr = "Tab";
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    keyStr = "Enter";
                }

                if (keyStr.length > 0) {
                    parts.push(keyStr);
                    let fullText = parts.join(" + ");
                    root.hotkeyText = fullText;
                    root.modifiers = mods;
                    root.vkCode = vk;
                    root.isRecording = false;
                    root.hotkeyChanged(fullText, mods, vk);
                    event.accepted = true;
                }
            }
        }
    }
}

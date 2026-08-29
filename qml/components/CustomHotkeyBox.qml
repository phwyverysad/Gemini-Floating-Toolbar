import QtQuick
import QtQuick.Controls

Item {
    id: root

    property string hotkeyText: "None"
    property int modifiers: 0
    property int vkCode: 0
    property bool isRecording: false
    property int customWidth: 280
    property int customHeight: 34

    signal hotkeyChanged(string text, int mods, int vk)

    width: customWidth
    height: customHeight

    Rectangle {
        id: bgBox
        anchors.fill: parent
        radius: 6
        color: root.isRecording ? (Theme.isDark ? "#2a374a" : "#eff6ff") : Theme.bgInput
        border.color: root.isRecording ? Theme.borderFocus : (mouseArea.containsMouse ? Qt.darker(Theme.borderLight, 1.4) : Theme.borderLight)
        border.width: root.isRecording ? 1.5 : 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: root.isRecording ? (AppManager.isThai ? "กดปุ่มลัดที่ต้องการ..." : "Press shortcut...") : root.hotkeyText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Normal
            color: root.isRecording ? Theme.primary : Theme.textPrimary
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.isRecording = true;
                keyListener.forceActiveFocus();
            }
        }

        Item {
            id: keyListener
            focus: root.isRecording
            Keys.onPressed: function(event) {
                if (!root.isRecording) return;

                if (event.key === Qt.Key_Escape) {
                    root.isRecording = false;
                    event.accepted = true;
                    return;
                }

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
                } else if (event.key === Qt.Key_QuoteLeft || event.key === Qt.Key_AsciiTilde) {
                    keyStr = "`";
                } else if (event.key === Qt.Key_Minus || event.key === Qt.Key_Underscore) {
                    keyStr = "-";
                } else if (event.key === Qt.Key_Equal || event.key === Qt.Key_Plus) {
                    keyStr = "=";
                } else if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BraceLeft) {
                    keyStr = "[";
                } else if (event.key === Qt.Key_BracketRight || event.key === Qt.Key_BraceRight) {
                    keyStr = "]";
                } else if (event.key === Qt.Key_Backslash || event.key === Qt.Key_Bar) {
                    keyStr = "\\";
                } else if (event.key === Qt.Key_Semicolon || event.key === Qt.Key_Colon) {
                    keyStr = ";";
                } else if (event.key === Qt.Key_Apostrophe || event.key === Qt.Key_QuoteDbl) {
                    keyStr = "'";
                } else if (event.key === Qt.Key_Comma || event.key === Qt.Key_Less) {
                    keyStr = ",";
                } else if (event.key === Qt.Key_Period || event.key === Qt.Key_Greater) {
                    keyStr = ".";
                } else if (event.key === Qt.Key_Slash || event.key === Qt.Key_Question) {
                    keyStr = "/";
                } else if (event.key === Qt.Key_Insert) {
                    keyStr = "Insert";
                } else if (event.key === Qt.Key_Delete) {
                    keyStr = "Delete";
                } else if (event.key === Qt.Key_Home) {
                    keyStr = "Home";
                } else if (event.key === Qt.Key_End) {
                    keyStr = "End";
                } else if (event.key === Qt.Key_PageUp) {
                    keyStr = "Page Up";
                } else if (event.key === Qt.Key_PageDown) {
                    keyStr = "Page Down";
                } else if (event.key === Qt.Key_Up) {
                    keyStr = "Up";
                } else if (event.key === Qt.Key_Down) {
                    keyStr = "Down";
                } else if (event.key === Qt.Key_Left) {
                    keyStr = "Left";
                } else if (event.key === Qt.Key_Right) {
                    keyStr = "Right";
                } else if (vk >= 0x60 && vk <= 0x69) {
                    keyStr = "Num " + (vk - 0x60);
                }

                if (keyStr.length > 0) {
                    parts.push(keyStr);
                    let fullHotkey = parts.join(" + ");
                    root.hotkeyText = fullHotkey;
                    root.modifiers = mods;
                    root.vkCode = vk;
                    root.isRecording = false;
                    root.hotkeyChanged(fullHotkey, mods, vk);
                    event.accepted = true;
                }
            }
        }
    }
}

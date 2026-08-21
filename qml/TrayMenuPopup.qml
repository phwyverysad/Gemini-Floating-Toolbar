import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "components"

Window {
    id: root

    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    visible: false

    width: 250
    height: menuCol.implicitHeight + 14

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }

    onActiveChanged: {
        if (!active && visible) {
            visible = false;
        }
    }

    function showAt(x, y) {
        let screenW = Screen.desktopAvailableWidth > 0 ? Screen.desktopAvailableWidth : Screen.width;
        let screenH = Screen.desktopAvailableHeight > 0 ? Screen.desktopAvailableHeight : Screen.height;
        let w = root.width;
        let h = root.height;

        let posX = x - (w / 2);
        let posY = y - h - 10;

        if (posX + w > screenW - 8) posX = screenW - w - 8;
        if (posX < 8) posX = 8;
        if (posY < 8) posY = y + 10;
        if (posY + h > screenH - 8) posY = screenH - h - 8;

        root.x = posX;
        root.y = posY;
        root.show();
        root.raise();
        root.requestActivate();
    }

    // Card Container (Fluent Windows 11 Design, Rounded Rectangles, Normal Font Weight)
    Rectangle {
        id: menuCard
        anchors.fill: parent
        anchors.margins: 2
        radius: 8
        color: Theme.isDark ? "#f2202227" : "#f8ffffff"
        border.color: Theme.borderLight
        border.width: 1

        Column {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 5
            spacing: 2

            // App Title Header
            Item {
                width: parent.width
                height: 22

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Google Gemini"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Normal
                    color: Theme.textSecondary
                }
            }

            // 1. Open Gemini
            MenuItemDelegate {
                titleText: AppManager.isThai ? "เปิด Google Gemini" : "Open Google Gemini"
                badgeText: "Alt + F"
                onTriggered: {
                    root.visible = false;
                    AppManager.toggleMainWindow();
                }
            }

            // 2. Capture Screen
            MenuItemDelegate {
                titleText: AppManager.isThai ? "แคปหน้าจอถาม Gemini" : "Capture Screen"
                badgeText: "Alt + Shift + S"
                onTriggered: {
                    root.visible = false;
                    AppManager.startSnipping();
                }
            }

            // 3. Highlight Text
            MenuItemDelegate {
                titleText: AppManager.isThai ? "คลุมข้อความถาม Gemini" : "Quick Ask Gemini"
                badgeText: "Ctrl + Caps"
                onTriggered: {
                    root.visible = false;
                    AppManager.startQuickAskFlow();
                }
            }

            // Divider
            Rectangle {
                width: parent.width - 8
                height: 1
                color: Theme.borderLight
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // 4. Settings Dialog
            MenuItemDelegate {
                titleText: AppManager.isThai ? "ตั้งค่าปุ่มลัดและคำสั่งด่วน..." : "Settings & Hotkeys..."
                badgeText: ""
                onTriggered: {
                    root.visible = false;
                    AppManager.showSettingsDialog();
                }
            }

            // 5. Language Toggle
            MenuItemDelegate {
                titleText: AppManager.isThai ? "ภาษา / Language (ไทย)" : "Language / ภาษา (EN)"
                badgeText: ""
                onTriggered: {
                    root.visible = false;
                    let cfg = AppManager.getSettings();
                    let newLang = (cfg.lang === "en") ? "th" : "en";
                    AppManager.setLanguage(newLang);
                }
            }

            // Divider
            Rectangle {
                width: parent.width - 8
                height: 1
                color: Theme.borderLight
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // 6. Exit
            MenuItemDelegate {
                titleText: AppManager.isThai ? "ออกจากโปรแกรม" : "Exit Application"
                badgeText: ""
                isDanger: true
                onTriggered: {
                    root.visible = false;
                    AppManager.exitApp();
                }
            }
        }
    }

    // Helper Component for Menu Item Row
    component MenuItemDelegate: Rectangle {
        property string titleText: ""
        property string badgeText: ""
        property bool isDanger: false

        signal triggered()

        width: parent ? parent.width : 240
        height: 30
        radius: 6
        color: itemMouse.containsMouse 
               ? (isDanger ? (Theme.isDark ? "#452424" : "#fee2e2") : Theme.bgCardHover) 
               : "transparent"

        Behavior on color { ColorAnimation { duration: 80 } }

        // Title Text Left Aligned
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: badgeRect.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: titleText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Normal
            color: isDanger && itemMouse.containsMouse ? Theme.danger : Theme.textPrimary
            elide: Text.ElideRight
        }

        // Right Badge for Shortcuts
        Rectangle {
            id: badgeRect
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: badgeText.length > 0
            width: badgeLabel.implicitWidth + 8
            height: 18
            radius: 4
            color: Theme.isDark ? "#282a30" : "#f1f5f9"
            border.color: Theme.borderLight
            border.width: 1

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: badgeText
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.Normal
                color: Theme.textSecondary
            }
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: triggered()
        }
    }
}

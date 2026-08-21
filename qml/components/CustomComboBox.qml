import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var model: []
    property int currentIndex: 0
    property string currentText: (model && model.length > currentIndex && currentIndex >= 0) ? model[currentIndex] : ""
    property int customWidth: 280
    property int customHeight: 34
    property bool isOpen: false

    signal activated(int index)

    width: customWidth
    height: customHeight

    Rectangle {
        id: bgBox
        anchors.fill: parent
        radius: 6
        color: Theme.bgInput
        border.color: root.isOpen ? Theme.borderFocus : (mouseArea.containsMouse ? Qt.darker(Theme.borderLight, 1.3) : Theme.borderLight)
        border.width: root.isOpen ? 1.5 : 1

        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }

        // Text Display
        Text {
            id: labelText
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: chevronIcon.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentText
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Normal
            color: Theme.textPrimary
            elide: Text.ElideRight
        }

        // Chevron Arrow
        Text {
            id: chevronIcon
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "⌄"
            font.pixelSize: 14
            font.weight: Font.Normal
            color: Theme.textSecondary
            rotation: root.isOpen ? 180 : 0
            transformOrigin: Item.Center
            Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.isOpen = !root.isOpen;
                if (root.isOpen) {
                    popupMenu.open();
                } else {
                    popupMenu.close();
                }
            }
        }
    }

    // Floating Popup Menu
    Popup {
        id: popupMenu
        y: root.height + 4
        width: root.width
        padding: 5
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: root.isOpen = false

        background: Rectangle {
            radius: 8
            color: Theme.bgDialog
            border.color: Theme.borderLight
            border.width: 1
        }

        contentItem: ListView {
            implicitHeight: Math.min(contentHeight, 220)
            clip: true
            model: root.model

            delegate: Rectangle {
                width: parent ? parent.width : 260
                height: 32
                radius: 6
                color: (index === root.currentIndex) 
                       ? (Theme.isDark ? "#2a374a" : "#eff6ff") 
                       : (itemMouse.containsMouse ? Theme.bgCardHover : "transparent")

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    color: (index === root.currentIndex) ? Theme.primary : Theme.textPrimary
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentIndex = index;
                        root.isOpen = false;
                        popupMenu.close();
                        root.activated(index);
                    }
                }
            }
        }
    }
}

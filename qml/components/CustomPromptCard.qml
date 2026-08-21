import QtQuick
import QtQuick.Controls

Item {
    id: root

    property int itemIndex: 0
    property int totalItems: 1
    property bool itemEnabled: true
    property string badgeText: "1"
    property string labelText: "คำตอบ (Answer)"
    property string promptText: ""
    property var mainScrollRef: null

    signal enabledChanged(int index, bool isEnabled)
    signal promptChanged(int index, string prompt)
    signal labelChanged(int index, string label)
    signal badgeChanged(int index, string badge)
    signal remove(int index)

    width: parent ? parent.width : 560
    height: cardCol.implicitHeight + 8

    Column {
        id: cardCol
        width: parent.width
        spacing: 5
        anchors.top: parent.top
        anchors.topMargin: 2
        opacity: root.itemEnabled ? 1.0 : 0.52

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        // 1. Header Label Row with Checkbox, Editable Badge, Editable Title, and Delete
        Row {
            width: parent.width
            spacing: 7

            // Checkbox: Toggle enabled/disabled for AI Toolbar
            Rectangle {
                id: enableCheckBox
                width: 20
                height: 20
                radius: 5
                color: root.itemEnabled ? Theme.primary : (checkMouse.containsMouse ? Theme.bgCardHover : Theme.bgInput)
                border.color: root.itemEnabled ? Theme.primary : (checkMouse.containsMouse ? Theme.primary : Theme.borderLight)
                border.width: 1.5
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: "#ffffff"
                    visible: root.itemEnabled
                }

                MouseArea {
                    id: checkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.itemEnabled = !root.itemEnabled
                        root.enabledChanged(root.itemIndex, root.itemEnabled)
                    }
                }
            }

            // Editable Shortcut Badge Box (e.g. 1, 2, A, Q, etc.)
            Rectangle {
                id: badgePill
                width: Math.max(30, badgeInput.implicitWidth + 12)
                height: 24
                radius: 6
                color: badgeInput.activeFocus ? (Theme.isDark ? "#2a374a" : "#eff6ff") : (badgeMouse.containsMouse ? Theme.bgCardHover : Theme.bgInput)
                border.color: badgeInput.activeFocus ? Theme.borderFocus : Theme.borderLight
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                TextInput {
                    id: badgeInput
                    text: root.badgeText
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    color: Theme.primary
                    anchors.centerIn: parent
                    selectByMouse: true
                    onTextEdited: {
                        root.badgeText = text
                        root.badgeChanged(root.itemIndex, text)
                    }
                    onEditingFinished: {
                        root.badgeText = text
                        root.badgeChanged(root.itemIndex, text)
                    }
                }

                MouseArea {
                    id: badgeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.IBeamCursor
                    onClicked: badgeInput.forceActiveFocus()
                }
            }

            // Editable Title Input
            Rectangle {
                width: parent.width - badgePill.width - enableCheckBox.width - (root.totalItems > 1 ? 48 : 22)
                height: 26
                radius: 6
                color: labelInput.activeFocus ? (Theme.isDark ? "#202227" : "#ffffff") : "transparent"
                border.color: labelInput.activeFocus ? Theme.borderFocus : "transparent"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                TextInput {
                    id: labelInput
                    text: root.labelText
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 4
                    selectByMouse: true
                    onTextEdited: {
                        root.labelText = text
                        root.labelChanged(root.itemIndex, text)
                    }
                    onEditingFinished: {
                        root.labelText = text
                        root.labelChanged(root.itemIndex, text)
                    }
                }
            }

            // Delete Button
            Rectangle {
                width: 22
                height: 22
                radius: 6
                color: delMouse.containsMouse ? (Theme.isDark ? "#452424" : "#fee2e2") : "transparent"
                border.color: delMouse.containsMouse ? Theme.danger : "transparent"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                visible: root.totalItems > 1

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 11
                    font.weight: Font.Normal
                    color: delMouse.containsMouse ? Theme.danger : Theme.textMuted
                }

                MouseArea {
                    id: delMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.remove(root.itemIndex)
                }
            }
        }

        // 2. TextArea Box (Auto-adjusting height, Wrap enabled, No horizontal scrollbar, Smooth Wheel Forwarding)
        Rectangle {
            width: parent.width
            height: Math.max(54, Math.min(130, editArea.contentHeight + 16))
            radius: 6
            color: Theme.bgInput
            border.color: editArea.activeFocus ? Theme.borderFocus : Theme.borderLight
            border.width: editArea.activeFocus ? 1.5 : 1

            ScrollView {
                id: innerScroll
                anchors.fill: parent
                anchors.margins: 3
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: (editArea.contentHeight > 115) ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

                TextArea {
                    id: editArea
                    width: innerScroll.width - (innerScroll.ScrollBar.vertical.visible ? 8 : 0)
                    text: root.promptText
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Normal
                    color: Theme.textPrimary
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    background: null
                    leftPadding: 6
                    rightPadding: 6
                    topPadding: 4
                    bottomPadding: 4

                    onTextChanged: {
                        if (root.promptText !== text) {
                            root.promptText = text
                            root.promptChanged(root.itemIndex, text)
                        }
                    }
                    onEditingFinished: {
                        root.promptText = text
                        root.promptChanged(root.itemIndex, text)
                    }
                }

                WheelHandler {
                    onWheel: function(event) {
                        if (root.mainScrollRef) {
                            let flick = root.mainScrollRef.contentItem;
                            if (flick) {
                                flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - event.angleDelta.y));
                            }
                        }
                    }
                }
            }
        }
    }
}

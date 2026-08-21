import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    property int itemIndex: 0
    property int totalItems: 1
    property string badgeText: "1"
    property string labelText: "คำตอบ (Answer)"
    property string promptText: ""
    property bool isEditingHeader: false

    signal promptChanged(int index, string prompt)
    signal labelChanged(int index, string label)
    signal badgeChanged(int index, string badge)
    signal moveUp(int index)
    signal moveDown(int index)
    signal remove(int index)

    width: parent ? parent.width : 600
    height: contentCol.implicitHeight + 20
    radius: 10
    color: Theme.bgCard
    border.color: Theme.borderLight
    border.width: 1

    Column {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        // Header Row: Badge + Label + Move Controls + Delete
        Row {
            width: parent.width
            spacing: 8

            // Badge circle
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter

                TextInput {
                    anchors.centerIn: parent
                    text: root.badgeText
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: "#ffffff"
                    maximumLength: 2
                    horizontalAlignment: TextInput.AlignHCenter
                    selectByMouse: true
                    onEditingFinished: {
                        root.badgeChanged(root.itemIndex, text)
                    }
                }
            }

            // Editable Title Label
            TextInput {
                id: labelInput
                width: parent.width - 24 - 8 - reorderRow.implicitWidth - 8 - deleteBtn.width - 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.labelText
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                selectByMouse: true
                clip: true
                onEditingFinished: {
                    root.labelChanged(root.itemIndex, text)
                }
            }

            // Reorder Buttons (Up / Down)
            Row {
                id: reorderRow
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 26
                    height: 26
                    radius: 6
                    color: upMouse.containsMouse ? Theme.bgCardHover : "transparent"
                    border.color: Theme.borderLight
                    opacity: root.itemIndex > 0 ? 1.0 : 0.35

                    Text {
                        anchors.centerIn: parent
                        text: "▲"
                        font.pixelSize: 10
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: upMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.itemIndex > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (root.itemIndex > 0) root.moveUp(root.itemIndex)
                        }
                    }
                }

                Rectangle {
                    width: 26
                    height: 26
                    radius: 6
                    color: downMouse.containsMouse ? Theme.bgCardHover : "transparent"
                    border.color: Theme.borderLight
                    opacity: root.itemIndex < root.totalItems - 1 ? 1.0 : 0.35

                    Text {
                        anchors.centerIn: parent
                        text: "▼"
                        font.pixelSize: 10
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: downMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.itemIndex < root.totalItems - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (root.itemIndex < root.totalItems - 1) root.moveDown(root.itemIndex)
                        }
                    }
                }
            }

            // Delete Button
            Rectangle {
                id: deleteBtn
                width: 26
                height: 26
                radius: 6
                color: delMouse.containsMouse ? (Theme.isDark ? "#3f1e1e" : "#fee2e2") : "transparent"
                border.color: delMouse.containsMouse ? Theme.danger : Theme.borderLight
                anchors.verticalCenter: parent.verticalCenter
                visible: root.totalItems > 1

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 11
                    font.weight: Font.Bold
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

        // Multi-line Prompt TextArea
        Rectangle {
            width: parent.width
            height: 64
            radius: 8
            color: Theme.bgInput
            border.color: promptArea.activeFocus ? Theme.borderFocus : Theme.borderLight
            border.width: promptArea.activeFocus ? 1.5 : 1

            ScrollView {
                anchors.fill: parent
                anchors.margins: 6
                clip: true

                TextArea {
                    id: promptArea
                    text: root.promptText
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textPrimary
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    background: null
                    placeholderText: AppManager.isThai ? "พิมพ์ข้อความพร้อมต์ที่ต้องการส่งให้ AI..." : "Enter prompt instruction for AI..."
                    placeholderTextColor: Theme.textMuted
                    onEditingFinished: {
                        root.promptChanged(root.itemIndex, text)
                    }
                    onTextChanged: {
                        root.promptText = text
                    }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Controls

Item {
    id: root

    property bool checked: false
    property string text: ""
    property int customSpacing: 10

    signal toggled(bool isChecked)

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: 28

    Row {
        id: rowLayout
        spacing: root.customSpacing
        anchors.verticalCenter: parent.verticalCenter

        // Box
        Rectangle {
            id: checkSquare
            width: 18
            height: 18
            radius: 5
            anchors.verticalCenter: parent.verticalCenter
            color: root.checked ? Theme.primary : (mouseArea.containsMouse ? Theme.bgCardHover : Theme.bgInput)
            border.color: root.checked ? Theme.primary : (mouseArea.containsMouse ? Qt.darker(Theme.borderLight, 1.4) : Theme.borderLight)
            border.width: 1.5

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: "#ffffff"
                visible: root.checked
                scale: root.checked ? 1.0 : 0.4
                Behavior on scale { NumberAnimation { duration: 100 } }
            }
        }

        // Text
        Text {
            id: labelText
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Normal
            color: Theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}

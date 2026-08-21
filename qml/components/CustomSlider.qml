import QtQuick
import QtQuick.Controls

Item {
    id: root

    property int from: 26
    property int to: 54
    property int value: 38
    property string unit: "px"

    signal valueModified(int val)

    width: parent ? parent.width : 300
    height: 34

    Row {
        anchors.fill: parent
        spacing: 12

        Slider {
            id: control
            from: root.from
            to: root.to
            stepSize: 1
            value: root.value
            width: parent.width - badgeBox.width - 12
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            onMoved: {
                let v = Math.round(value);
                if (root.value !== v) {
                    root.value = v;
                    root.valueModified(v);
                }
            }

            background: Rectangle {
                x: control.leftPadding
                y: control.topPadding + control.availableHeight / 2 - height / 2
                implicitWidth: 200
                implicitHeight: 6
                width: control.availableWidth
                height: 6
                radius: 3
                color: Theme.isDark ? "#282a30" : "#e2e8f0"

                Rectangle {
                    width: control.visualPosition * parent.width
                    height: parent.height
                    color: Theme.primary
                    radius: 3
                }
            }

            handle: Rectangle {
                x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
                y: control.topPadding + control.availableHeight / 2 - height / 2
                implicitWidth: 20
                implicitHeight: 20
                radius: 10
                color: "#ffffff"
                border.color: control.pressed ? Theme.primaryHover : (control.hovered ? Theme.primaryHover : Theme.primary)
                border.width: 3

                scale: control.pressed ? 1.2 : (control.hovered ? 1.1 : 1.0)
                Behavior on scale { NumberAnimation { duration: 60 } }
            }
        }

        // Value Badge Box
        Rectangle {
            id: badgeBox
            width: 68
            height: 28
            radius: 6
            color: Theme.bgInput
            border.color: Theme.borderLight
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                text: `${root.value} ${root.unit}`
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Normal
                color: Theme.primary
            }
        }
    }
}

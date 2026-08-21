import QtQuick
import QtQuick.Controls

Button {
    id: control

    property string variant: "secondary" // "primary" | "secondary" | "danger" | "ghost" | "icon"
    property int customRadius: 8
    property color customBgColor: "transparent"
    property color customTextColor: "transparent"

    implicitHeight: 38
    implicitWidth: Math.max(90, contentItem.implicitWidth + 24)

    font.family: Theme.fontFamily
    font.pixelSize: 13
    font.weight: Font.Medium

    background: Rectangle {
        implicitWidth: 100
        implicitHeight: 38
        radius: control.customRadius

        color: {
            if (control.customBgColor !== "transparent") return control.customBgColor;
            if (control.variant === "primary") {
                return control.down ? Theme.primaryHover : (control.hovered ? Qt.lighter(Theme.primary, 1.1) : Theme.primary);
            } else if (control.variant === "danger") {
                return control.down ? Theme.dangerHover : (control.hovered ? Qt.lighter(Theme.danger, 1.1) : Theme.danger);
            } else if (control.variant === "ghost") {
                return control.hovered ? Theme.bgCardHover : "transparent";
            } else {
                // Secondary / default
                return control.down ? Qt.darker(Theme.bgCard, 1.05) : (control.hovered ? Theme.bgCardHover : Theme.bgCard);
            }
        }

        border.color: {
            if (control.variant === "primary" || control.variant === "danger" || control.variant === "ghost") {
                return "transparent";
            }
            return control.hovered ? Theme.borderFocus : Theme.borderLight;
        }
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    contentItem: Text {
        text: control.text
        font: control.font
        color: {
            if (control.customTextColor !== "transparent") return control.customTextColor;
            if (control.variant === "primary" || control.variant === "danger") {
                return Theme.primaryText;
            }
            return Theme.textPrimary;
        }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}

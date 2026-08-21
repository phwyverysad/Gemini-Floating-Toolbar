import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "components"

Window {
    id: root

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.NoDropShadowWindowHint
    color: "transparent"
    visible: false

    x: 0
    y: 0
    width: Screen.width
    height: Screen.height

    property bool isSelecting: false
    property int startX: -100
    property int startY: -100
    property int currentX: -100
    property int currentY: -100

    property int selX: Math.min(startX, currentX)
    property int selY: Math.min(startY, currentY)
    property int selW: Math.abs(currentX - startX)
    property int selH: Math.abs(currentY - startY)

    function resetSelection() {
        root.isSelecting = false;
        root.startX = -100;
        root.startY = -100;
        root.currentX = -100;
        root.currentY = -100;
    }

    onVisibleChanged: {
        if (!visible) {
            resetSelection();
        }
    }

    function startSnipping() {
        resetSelection();
        root.show();
        root.raise();
        root.requestActivate();
        keyHandler.forceActiveFocus();
    }

    function finishSnipping() {
        let finalX = root.selX;
        let finalY = root.selY;
        let finalW = root.selW;
        let finalH = root.selH;

        resetSelection();
        root.hide();

        if (finalW > 10 && finalH > 10) {
            AppManager.processScreenCrop(finalX, finalY, finalW, finalH);
        } else {
            AppManager.cancelAction();
        }
    }

    function cancelSnipping() {
        resetSelection();
        root.hide();
        AppManager.cancelAction();
    }

    Item {
        id: keyHandler
        focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.cancelSnipping();
                event.accepted = true;
            }
        }
    }

    // Pure GPU Rectangle Overlays (Zero-Canvas Framebuffer Texture Latency, Zero Flicker!)
    Item {
        id: dimContainer
        anchors.fill: parent

        // Top Dim (Full screen when not selecting, or top band when selecting)
        Rectangle {
            x: 0
            y: 0
            width: root.width
            height: root.isSelecting ? root.selY : root.height
            color: "#73000000" // 45% black
        }

        // Bottom Dim
        Rectangle {
            visible: root.isSelecting && root.selH > 0
            x: 0
            y: root.selY + root.selH
            width: root.width
            height: Math.max(0, root.height - (root.selY + root.selH))
            color: "#73000000"
        }

        // Left Dim
        Rectangle {
            visible: root.isSelecting && root.selW > 0 && root.selH > 0
            x: 0
            y: root.selY
            width: root.selX
            height: root.selH
            color: "#73000000"
        }

        // Right Dim
        Rectangle {
            visible: root.isSelecting && root.selW > 0 && root.selH > 0
            x: root.selX + root.selW
            y: root.selY
            width: Math.max(0, root.width - (root.selX + root.selW))
            height: root.selH
            color: "#73000000"
        }
    }

    // Selection Rectangle Outline
    Rectangle {
        id: selRect
        visible: root.isSelecting && root.selW > 0 && root.selH > 0
        x: root.selX
        y: root.selY
        width: root.selW
        height: root.selH
        color: "transparent"
        border.color: "#3b82f6"
        border.width: 2

        // Smart Snipping Dimension Badge (e.g. 800 × 600 px)
        Rectangle {
            id: dimBadge
            visible: root.isSelecting && parent.width > 60 && parent.height > 40
            width: dimText.implicitWidth + 16
            height: 24
            radius: 6
            color: "#e60f172a"
            border.color: "#33ffffff"
            anchors.bottom: parent.top
            anchors.bottomMargin: 6
            anchors.left: parent.left

            Text {
                id: dimText
                anchors.centerIn: parent
                text: `${root.selW} × ${root.selH} px`
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Normal
                color: "#ffffff"
            }
        }
    }

    // Mouse Selection Area
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.CrossCursor

        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.startX = mouse.x;
                root.startY = mouse.y;
                root.currentX = mouse.x;
                root.currentY = mouse.y;
                root.isSelecting = true;
            } else if (mouse.button === Qt.RightButton) {
                root.cancelSnipping();
            }
        }

        onPositionChanged: function(mouse) {
            if (root.isSelecting) {
                root.currentX = mouse.x;
                root.currentY = mouse.y;
            }
        }

        onReleased: function(mouse) {
            if (root.isSelecting && mouse.button === Qt.LeftButton) {
                root.currentX = mouse.x;
                root.currentY = mouse.y;
                root.finishSnipping();
            }
        }
    }
}

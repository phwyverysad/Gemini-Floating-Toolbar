import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "components"

Window {
    id: root

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    color: "transparent"
    visible: false

    property string targetType: "image"
    property var activePrompts: []
    property int anchorX: 0
    property int anchorY: 0
    property string placementMode: "auto"

    // Custom Ask Mode State
    property bool isCustomAskMode: false
    property string customQueryText: ""
    property int pendingPromptIndex: -1
    property bool isExiting: false
    property bool wasActivated: false

    onActiveChanged: {
        if (active) {
            wasActivated = true;
        } else if (wasActivated && visible && !isExiting) {
            AppManager.removeToolbarKeyboardHook();
            root.animateHide();
        }
    }

    // Drag Handle Helper
    property point dragStartPoint: Qt.point(0, 0)

    // Dynamic Sizing Metrics based on AppManager.toolbarHeight
    property int barHeight: (AppManager.toolbarHeight >= 26) ? AppManager.toolbarHeight : 38
    readonly property int btnHeight: Math.max(22, root.barHeight - 8)
    readonly property int badgeSize: Math.max(16, root.barHeight - 18)
    readonly property int fontSize: Math.max(10, Math.min(13, Math.round(root.barHeight * 0.30)))
    readonly property int badgeFontSize: Math.max(9, Math.min(11, Math.round(root.barHeight * 0.24)))

    property var cancelConfig: AppManager.cancelButton || ({ badge: "Esc", label: (AppManager.isThai ? "ยกเลิก" : "Cancel"), enabled: true })

    width: mainContainer.width + 32
    height: mainContainer.height + 32

    property string pendingPromptText: ""

    Connections {
        target: AppManager
        function onRequestHideToolbar() {
            root.animateHide();
        }
        function onRequestHideImmediateToolbar() {
            root.hideImmediate();
        }
        function onSettingsChanged() {
            root.reloadPrompts();
        }
        function onRequestTriggerToolbarAction(visualIndex) {
            if (!root.isCustomAskMode && visualIndex >= 0 && visualIndex < root.activePrompts.length) {
                root.triggerPromptWithAnim(visualIndex);
            }
        }
        function onRequestOpenCustomAsk() {
            if (!root.isCustomAskMode) {
                root.openCustomAskMode();
            }
        }
    }

    // Keyboard Shortcuts for active window fallback
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.isCustomAskMode) {
                root.exitCustomAskMode();
            } else {
                root.animateHide();
            }
        }
    }
    Shortcut { sequence: "1"; onActivated: if (!root.isCustomAskMode && root.activePrompts.length > 0) root.triggerPromptWithAnim(0) }
    Shortcut { sequence: "2"; onActivated: if (!root.isCustomAskMode && root.activePrompts.length > 1) root.triggerPromptWithAnim(1) }
    Shortcut { sequence: "3"; onActivated: if (!root.isCustomAskMode && root.activePrompts.length > 2) root.triggerPromptWithAnim(2) }
    Shortcut { sequence: "4"; onActivated: if (!root.isCustomAskMode && root.activePrompts.length > 3) root.triggerPromptWithAnim(3) }
    Shortcut { sequence: "5"; onActivated: if (!root.isCustomAskMode && root.activePrompts.length > 4) root.triggerPromptWithAnim(4) }
    Shortcut { sequence: "6"; onActivated: if (!root.isCustomAskMode && root.activePrompts.length > 5) root.triggerPromptWithAnim(5) }
    Shortcut { sequence: "7"; onActivated: if (!root.isCustomAskMode && root.activePrompts.length > 6) root.triggerPromptWithAnim(6) }
    Shortcut { sequence: "8"; onActivated: if (!root.isCustomAskMode && root.activePrompts.length > 7) root.triggerPromptWithAnim(7) }
    Shortcut { sequence: "9"; onActivated: if (!root.isCustomAskMode && root.activePrompts.length > 8) root.triggerPromptWithAnim(8) }
    Shortcut { sequence: "0"; onActivated: if (!root.isCustomAskMode) root.openCustomAskMode() }
    Shortcut { sequence: "T"; onActivated: if (!root.isCustomAskMode) root.openCustomAskMode() }

    function reloadPrompts() {
        let combined = [];

        function addPromptItem(p) {
            if (!p) return;
            let isEn = (p.enabled === undefined || p.enabled === true || p.enabled === "true" || p.enabled === 1);
            if (!isEn) return;
            combined.push(p);
        }

        function addPromptsFromList(list) {
            if (!list) return;
            let len = list.length !== undefined ? list.length : 0;
            for (let i = 0; i < len; i++) {
                addPromptItem(list[i]);
            }
        }

        // 1. Primary category based on targetType
        if (root.targetType === "image") {
            addPromptsFromList(AppManager.imagePrompts);
        } else if (root.targetType === "text") {
            addPromptsFromList(AppManager.textPrompts);
        } else {
            let cats = AppManager.categories || [];
            for (let i = 0; i < cats.length; i++) {
                if (cats[i].id === root.targetType) {
                    addPromptsFromList(cats[i].prompts);
                    break;
                }
            }
        }

        // 2. Append custom user-created categories (categories other than 'image', 'text', 'custom')
        let allCats = AppManager.categories || [];
        for (let i = 0; i < allCats.length; i++) {
            let cat = allCats[i];
            if (cat.id !== "image" && cat.id !== "text" && cat.id !== "custom" && cat.id !== root.targetType) {
                let pList = cat.prompts;
                if (pList && (Array.isArray(pList) || pList.length !== undefined)) {
                    for (let j = 0; j < pList.length; j++) {
                        addPromptItem(pList[j]);
                    }
                }
            }
        }

        // 3. Fallback if empty
        if (combined.length === 0) {
            addPromptsFromList(AppManager.imagePrompts);
        }

        root.activePrompts = combined;
    }

    function getShortLabel(fullLabel) {
        if (!fullLabel) return "";
        let idx = fullLabel.indexOf("(");
        if (idx > 0) {
            return fullLabel.substring(0, idx).trim();
        }
        return fullLabel.trim();
    }

    function openCustomAskMode() {
        root.isCustomAskMode = true;
        root.customQueryText = "";
        AppManager.removeToolbarKeyboardHook();
        root.requestActivate();
        customInput.forceActiveFocus();
    }

    function exitCustomAskMode() {
        root.isCustomAskMode = false;
        AppManager.installToolbarKeyboardHook(root.targetType);
    }

    function submitCustomAsk() {
        let q = customInput.text.trim();
        root.animateCustomSubmit(q);
    }

    function hideImmediate() {
        openAnim.stop();
        closeAnim.stop();
        triggerExitAnim.stop();
        customSubmitExitAnim.stop();
        mainContainer.opacity = 0.0;
        mainContainer.scale = 0.88;
        root.visible = false;
        root.isExiting = false;
        root.isCustomAskMode = false;
        root.wasActivated = false;
        AppManager.removeToolbarKeyboardHook();
    }

    function showToolbar(type, x, y) {
        openAnim.stop();
        closeAnim.stop();
        triggerExitAnim.stop();
        customSubmitExitAnim.stop();

        mainContainer.opacity = 0.0;
        mainContainer.scale = 0.88;
        root.visible = false;

        root.targetType = type || "image";
        root.anchorX = x;
        root.anchorY = y;
        root.isCustomAskMode = false;
        root.customQueryText = "";
        root.isExiting = false;
        root.wasActivated = false;
        root.placementMode = AppManager.toolbarPlacement || "auto";
        root.cancelConfig = AppManager.cancelButton || { badge: "Esc", label: (AppManager.isThai ? "ยกเลิก" : "Cancel"), enabled: true };
        
        root.reloadPrompts();

        // Multi-monitor screen detection with Qt 6 standard geometry
        let targetScreen = null;
        let screenList = Qt.application.screens;
        if (screenList && screenList.length > 0) {
            for (let i = 0; i < screenList.length; i++) {
                let s = screenList[i];
                let geo = s.virtualGeometry || s.geometry || Qt.rect(0, 0, s.width, s.height);
                let sVx = geo.x;
                let sVy = geo.y;
                let sVw = geo.width;
                let sVh = geo.height;
                if (x >= sVx && x < (sVx + sVw) && y >= sVy && y < (sVy + sVh)) {
                    targetScreen = s;
                    break;
                }
            }
        }
        if (!targetScreen) {
            targetScreen = Screen;
        }

        let targetGeo = targetScreen.virtualGeometry || targetScreen.geometry || Qt.rect(0, 0, targetScreen.width, targetScreen.height);
        let sX = targetGeo.x;
        let sY = targetGeo.y;
        let screenW = targetGeo.width;
        let screenH = targetGeo.height;
        if (sX === 0 && sY === 0 && targetScreen.desktopAvailableWidth > 0 && targetScreen.desktopAvailableHeight > 0) {
            screenW = targetScreen.desktopAvailableWidth;
            screenH = targetScreen.desktopAvailableHeight;
        }
        
        let promptCount = root.activePrompts.length;
        let estimatedW = Math.max(340, promptCount * 78 + 150);
        let actualW = estimatedW;
        let actualH = root.barHeight + 32;

        if (root.placementMode === "center") {
            root.x = Math.round(sX + (screenW - actualW) / 2);
            root.y = Math.round(sY + (screenH - actualH) / 2);
        } else {
            let posX = Math.round(x - (actualW / 2));
            let posY = (type === "text") ? Math.round(y - actualH - 12) : Math.round(y + 12);

            if (posY < sY + 20) posY = Math.round(y + 24);
            if (posY + actualH > sY + screenH - 20) posY = sY + screenH - actualH - 20;
            if (posX < sX + 20) posX = sX + 20;
            if (posX + actualW > sX + screenW - 20) posX = sX + screenW - actualW - 20;

            root.x = posX;
            root.y = posY;
        }

        root.show();
        root.raise();
        root.requestActivate();
        openAnim.restart();
    }

    function animateHide() {
        if (root.isExiting) return;
        AppManager.removeToolbarKeyboardHook();
        root.isExiting = true;
        closeAnim.restart();
    }

    function triggerPromptWithAnim(index) {
        if (index < 0 || index >= root.activePrompts.length) return;
        if (root.isExiting) return;
        root.isExiting = true;
        root.pendingPromptIndex = index;
        let pObj = root.activePrompts[index];
        root.pendingPromptText = pObj && pObj.prompt ? pObj.prompt : "";
        triggerExitAnim.restart();
    }

    function animateCustomSubmit(promptText) {
        if (root.isExiting) return;
        root.isExiting = true;
        root.customQueryText = promptText;
        customSubmitExitAnim.restart();
    }

    // --- ANIMATIONS ---
    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: mainContainer
            property: "scale"
            from: 0.88
            to: 1.0
            duration: 200
            easing.type: Easing.OutBack
            easing.overshoot: 1.12
        }
        NumberAnimation {
            target: mainContainer
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 150
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: mainContainer
            property: "yOffset"
            from: 10
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: mainContainer
            property: "scale"
            to: 0.90
            duration: 120
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: mainContainer
            property: "opacity"
            to: 0.0
            duration: 100
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: mainContainer
            property: "yOffset"
            to: 6
            duration: 120
            easing.type: Easing.InQuad
        }
        onFinished: {
            root.visible = false;
            root.isCustomAskMode = false;
            root.isExiting = false;
            AppManager.cancelAction();
        }
    }

    ParallelAnimation {
        id: triggerExitAnim
        NumberAnimation {
            target: mainContainer
            property: "scale"
            to: 0.94
            duration: 100
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: mainContainer
            property: "opacity"
            to: 0.0
            duration: 90
            easing.type: Easing.InQuad
        }
        onFinished: {
            root.visible = false;
            root.isCustomAskMode = false;
            root.isExiting = false;
            let pText = root.pendingPromptText;
            root.pendingPromptText = "";
            let idx = root.pendingPromptIndex;
            root.pendingPromptIndex = -1;
            if (pText && pText.length > 0) {
                AppManager.triggerPromptDirect(pText, root.targetType);
            } else {
                AppManager.triggerAction(idx, root.targetType);
            }
        }
    }

    ParallelAnimation {
        id: customSubmitExitAnim
        NumberAnimation {
            target: mainContainer
            property: "scale"
            to: 0.94
            duration: 100
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: mainContainer
            property: "opacity"
            to: 0.0
            duration: 90
            easing.type: Easing.InQuad
        }
        onFinished: {
            root.visible = false;
            root.isCustomAskMode = false;
            root.isExiting = false;
            AppManager.triggerCustomPrompt(root.customQueryText, root.targetType);
        }
    }

    // Main Floating Box Container (Polished Fluent Design)
    Rectangle {
        id: mainContainer
        property real yOffset: 0
        anchors.centerIn: parent
        anchors.verticalCenterOffset: yOffset

        width: root.isCustomAskMode ? 460 : (buttonRow.implicitWidth + 14)
        height: root.barHeight
        radius: 8
        clip: true
        color: Theme.isDark ? "#f022242a" : "#ffffff"
        border.color: Theme.isDark ? "#353942" : "#e2e8f0"
        border.width: 1

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // Mode 1: Quick Prompt Buttons Row
        Row {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 3
            opacity: root.isCustomAskMode ? 0.0 : 1.0
            visible: opacity > 0.0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            // 0. Drag Handle (6 dots in 2 vertical columns: ⋮⋮)
            Rectangle {
                id: dragHandleBtn
                width: 18
                height: root.btnHeight
                radius: 4
                color: dragMouse.containsMouse ? (Theme.isDark ? "#343844" : "#edf2f7") : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                // 2 columns of 3 dots
                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    spacing: 3

                    Repeater {
                        model: 6
                        Rectangle {
                            width: 3
                            height: 3
                            radius: 1.5
                            color: dragMouse.containsMouse ? Theme.textPrimary : Theme.textMuted
                        }
                    }
                }

                MouseArea {
                    id: dragMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: dragMouse.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    onPressed: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            root.startSystemMove();
                        }
                    }
                }
            }

            // Preset Action Buttons
            Repeater {
                model: root.activePrompts

                delegate: Rectangle {
                    id: btnCard
                    width: btnContent.implicitWidth + 14
                    height: root.btnHeight
                    radius: 6
                    color: btnMouse.containsMouse ? (Theme.isDark ? "#343844" : "#edf2f7") : "transparent"
                    border.color: btnMouse.containsMouse ? (Theme.isDark ? "#484f5e" : "#cbd5e1") : "transparent"
                    border.width: 1

                    scale: btnMouse.pressed ? 0.96 : (btnMouse.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 90 } }

                    Row {
                        id: btnContent
                        anchors.centerIn: parent
                        spacing: 6

                        // Badge Box (1, 2, 3...)
                        Rectangle {
                            width: Math.max(root.badgeSize, badgeTextObj.implicitWidth + 6)
                            height: root.badgeSize
                            radius: 4
                            color: Theme.isDark ? "#2b2f38" : "#f1f5f9"
                            border.color: Theme.isDark ? "#3f4450" : "#e2e8f0"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: badgeTextObj
                                anchors.centerIn: parent
                                text: modelData.badge ? modelData.badge : String(index + 1)
                                font.family: Theme.fontFamily
                                font.pixelSize: root.badgeFontSize
                                font.weight: Font.Normal
                                color: Theme.textSecondary
                            }
                        }

                        // Label
                        Text {
                            text: root.getShortLabel(modelData.label)
                            font.family: Theme.fontFamily
                            font.pixelSize: root.fontSize
                            font.weight: Font.Normal
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.triggerPromptWithAnim(index)
                    }
                }
            }

            // Mode 1: ถามเอง (Custom Ask Button)
            Rectangle {
                id: customAskBtn
                width: customAskContent.implicitWidth + 14
                height: root.btnHeight
                radius: 6
                color: customAskMouse.containsMouse ? (Theme.isDark ? "#343844" : "#edf2f7") : "transparent"
                border.color: customAskMouse.containsMouse ? (Theme.isDark ? "#484f5e" : "#cbd5e1") : "transparent"
                border.width: 1

                scale: customAskMouse.pressed ? 0.96 : (customAskMouse.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 90 } }

                Row {
                    id: customAskContent
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: Math.max(root.badgeSize, customBadgeText.implicitWidth + 6)
                        height: root.badgeSize
                        radius: 4
                        color: Theme.isDark ? "#2b2f38" : "#f1f5f9"
                        border.color: Theme.isDark ? "#3f4450" : "#e2e8f0"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: customBadgeText
                            anchors.centerIn: parent
                            text: "?"
                            font.family: Theme.fontFamily
                            font.pixelSize: root.badgeFontSize
                            font.weight: Font.Normal
                            color: Theme.textSecondary
                        }
                    }

                    Text {
                        text: AppManager.isThai ? "ถามเอง" : "Custom Ask"
                        font.family: Theme.fontFamily
                        font.pixelSize: root.fontSize
                        font.weight: Font.Normal
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: customAskMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openCustomAskMode()
                }
            }

            // Cancel Button (Clean text matching other buttons)
            Rectangle {
                id: cancelBtn
                visible: root.cancelConfig.enabled !== false
                width: cancelContent.implicitWidth + 14
                height: root.btnHeight
                radius: 6
                color: cancelMouse.containsMouse ? (Theme.isDark ? "#3f2020" : "#fee2e2") : "transparent"
                border.color: cancelMouse.containsMouse ? (Theme.isDark ? "#7f1d1d" : "#fca5a5") : "transparent"
                border.width: 1

                scale: cancelMouse.pressed ? 0.96 : (cancelMouse.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 90 } }

                Row {
                    id: cancelContent
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: Math.max(root.badgeSize, cancelBadgeText.implicitWidth + 6)
                        height: root.badgeSize
                        radius: 4
                        color: Theme.isDark ? "#2b2f38" : "#f1f5f9"
                        border.color: Theme.isDark ? "#3f4450" : "#e2e8f0"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: cancelBadgeText
                            anchors.centerIn: parent
                            text: root.cancelConfig.badge ? root.cancelConfig.badge : "Esc"
                            font.family: Theme.fontFamily
                            font.pixelSize: root.badgeFontSize
                            font.weight: Font.Normal
                            color: cancelMouse.containsMouse ? Theme.danger : Theme.textSecondary
                        }
                    }

                    Text {
                        text: root.cancelConfig.label ? root.cancelConfig.label : (AppManager.isThai ? "ยกเลิก" : "Cancel")
                        font.family: Theme.fontFamily
                        font.pixelSize: root.fontSize
                        font.weight: Font.Normal
                        color: cancelMouse.containsMouse ? Theme.danger : Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.animateHide()
                }
            }
        }

        // Mode 2: Inline Custom Question Input Field
        Row {
            id: customInputRow
            anchors.fill: parent
            anchors.margins: 4
            spacing: 6
            opacity: root.isCustomAskMode ? 1.0 : 0.0
            visible: opacity > 0.0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            // Drag Handle on custom input mode too
            Rectangle {
                width: 14
                height: parent.height
                radius: 4
                color: customDragMouse.containsMouse ? (Theme.isDark ? "#343844" : "#edf2f7") : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    spacing: 2.5

                    Repeater {
                        model: 6
                        Rectangle {
                            width: 2.5
                            height: 2.5
                            radius: 1.25
                            color: customDragMouse.containsMouse ? Theme.textPrimary : Theme.textMuted
                        }
                    }
                }

                MouseArea {
                    id: customDragMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: customDragMouse.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    onPressed: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            root.startSystemMove();
                        }
                    }
                }
            }

            // Back button
            Rectangle {
                width: 26
                height: parent.height
                radius: 6
                color: backMouse.containsMouse ? Theme.bgCardHover : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "←"
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.exitCustomAskMode()
                }
            }

            // Input Field Box
            Rectangle {
                width: parent.width - 14 - 26 - sendBtn.width - 24
                height: parent.height
                radius: 6
                color: Theme.bgInput
                border.color: customInput.activeFocus ? Theme.borderFocus : Theme.borderLight
                border.width: 1

                TextInput {
                    id: customInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    color: Theme.textPrimary
                    selectByMouse: true

                    Text {
                        text: AppManager.isThai ? "พิมพ์คำถามที่ต้องการถาม Gemini..." : "Type your question for Gemini..."
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: Theme.textMuted
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        visible: !customInput.text && !customInput.activeFocus
                    }

                    onAccepted: root.submitCustomAsk()
                }
            }

            // Send Button
            Rectangle {
                id: sendBtn
                width: sendText.implicitWidth + 16
                height: parent.height
                radius: 6
                color: sendMouse.containsMouse ? "#1d4ed8" : "#2563eb"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: sendText
                    anchors.centerIn: parent
                    text: AppManager.isThai ? "ส่งคำถาม" : "Send"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Normal
                    color: "#ffffff"
                }

                MouseArea {
                    id: sendMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submitCustomAsk()
                }
            }
        }
    }
}

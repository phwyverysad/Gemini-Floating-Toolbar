import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "components"

Window {
    id: root

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.NoDropShadowWindowHint
    color: "transparent"
    visible: false

    function updateMultiScreenGeometry() {
        let vGeo = AppManager.getVirtualDesktopGeometry();
        if (vGeo && vGeo.width > 100 && vGeo.height > 100) {
            root.x = vGeo.x;
            root.y = vGeo.y;
            root.width = vGeo.width;
            root.height = vGeo.height;
        } else {
            let screens = Qt.application.screens;
            if (screens && screens.length > 0) {
                let minX = 0, minY = 0, maxX = 0, maxY = 0;
                for (let i = 0; i < screens.length; i++) {
                    let s = screens[i];
                    let geo = s.virtualGeometry || s.geometry || Qt.rect(0, 0, s.width, s.height);
                    let sx = geo.x, sy = geo.y, sw = geo.width, sh = geo.height;
                    if (i === 0) {
                        minX = sx; minY = sy; maxX = sx + sw; maxY = sy + sh;
                    } else {
                        minX = Math.min(minX, sx);
                        minY = Math.min(minY, sy);
                        maxX = Math.max(maxX, sx + sw);
                        maxY = Math.max(maxY, sy + sh);
                    }
                }
                root.x = minX;
                root.y = minY;
                root.width = Math.max(100, maxX - minX);
                root.height = Math.max(100, maxY - minY);
            } else {
                root.x = 0;
                root.y = 0;
                root.width = Screen.width;
                root.height = Screen.height;
            }
        }
    }

    property var snapshotTimestamp: 0
    property string captureMode: "freeform" // "freeform" | "window" | "smart"
    property rect smartRect: Qt.rect(0, 0, 0, 0)
    property var hoveredWindow: ({ found: false, x: 0, y: 0, width: 0, height: 0, title: "" })

    // Left Mouse Drag (Freeform Selection)
    property bool isSelecting: false
    property int startX: -100
    property int startY: -100
    property int currentX: -100
    property int currentY: -100
    property int mouseX: -100
    property int mouseY: -100

    property int selX: Math.min(startX, currentX)
    property int selY: Math.min(startY, currentY)
    property int selW: Math.abs(currentX - startX)
    property int selH: Math.abs(currentY - startY)

    // Right Mouse Drag (Smart Auto-Fit / AI Guess)
    property bool isRightSelecting: false
    property int rightStartX: -100
    property int rightStartY: -100
    property int rightCurrentX: -100
    property int rightCurrentY: -100

    property int rightSelX: Math.min(rightStartX, rightCurrentX)
    property int rightSelY: Math.min(rightStartY, rightCurrentY)
    property int rightSelW: Math.abs(rightCurrentX - rightStartX)
    property int rightSelH: Math.abs(rightCurrentY - rightStartY)

    // Interactive Confirmed Selection Box State
    property bool hasConfirmedSelection: false
    property int confirmedX: 0
    property int confirmedY: 0
    property int confirmedW: 0
    property int confirmedH: 0

    // Custom toolbar position (When user drags toolbar independently)
    property bool hasCustomToolbarPos: false
    property real customToolbarX: 0
    property real customToolbarY: 0

    // Custom Ask inline input state
    property bool isCustomAskMode: false

    property bool isAnyDragging: isSelecting || isRightSelecting

    property int maskX: hasConfirmedSelection ? confirmedX : (isRightSelecting ? rightSelX : selX)
    property int maskY: hasConfirmedSelection ? confirmedY : (isRightSelecting ? rightSelY : selY)
    property int maskW: hasConfirmedSelection ? confirmedW : (isRightSelecting ? rightSelW : selW)
    property int maskH: hasConfirmedSelection ? confirmedH : (isRightSelecting ? rightSelH : selH)

    // Sizing metrics matching FloatingToolbar.qml
    property int barHeight: (AppManager.toolbarHeight >= 26) ? AppManager.toolbarHeight : 38
    readonly property int btnHeight: Math.max(22, root.barHeight - 8)
    readonly property int badgeSize: Math.max(16, root.barHeight - 18)
    readonly property int fontSize: Math.max(10, Math.min(13, Math.round(root.barHeight * 0.30)))
    readonly property int badgeFontSize: Math.max(9, Math.min(11, Math.round(root.barHeight * 0.24)))

    property var activeImagePrompts: {
        let combined = [];
        function addPromptItem(p) {
            if (!p) return;
            let isEn = (p.enabled === undefined || p.enabled === true || p.enabled === "true" || p.enabled === 1);
            if (!isEn) return;
            combined.push(p);
        }

        // 1. Primary image prompts
        let imgList = AppManager.imagePrompts || [];
        for (let i = 0; i < imgList.length; i++) {
            addPromptItem(imgList[i]);
        }

        // 2. Custom user-created categories
        let allCats = AppManager.categories || [];
        for (let i = 0; i < allCats.length; i++) {
            let cat = allCats[i];
            if (cat.id !== "image" && cat.id !== "text" && cat.id !== "custom") {
                let pList = cat.prompts;
                if (pList && (Array.isArray(pList) || pList.length !== undefined)) {
                    for (let j = 0; j < pList.length; j++) {
                        addPromptItem(pList[j]);
                    }
                }
            }
        }

        if (combined.length === 0) {
            for (let i = 0; i < imgList.length; i++) addPromptItem(imgList[i]);
        }
        return combined;
    }

    function getShortLabel(fullLabel) {
        if (!fullLabel) return "";
        let idx = fullLabel.indexOf("(");
        if (idx > 0) return fullLabel.substring(0, idx).trim();
        return fullLabel.trim();
    }

    function setCaptureMode(mode) {
        if (root.hasConfirmedSelection) return;
        root.captureMode = mode;
        if (mode === "window") {
            root.smartRect = Qt.rect(0, 0, 0, 0);
            if (root.mouseX > 0 && root.mouseY > 0) {
                root.hoveredWindow = AppManager.detectWindowAt(root.mouseX, root.mouseY);
            }
        } else if (mode === "smart") {
            root.hoveredWindow = ({ found: false, x: 0, y: 0, width: 0, height: 0, title: "" });
            if (root.mouseX > 0 && root.mouseY > 0) {
                let detected = AppManager.detectElementBounds(root.mouseX, root.mouseY);
                if (detected && detected.width > 4 && detected.height > 4) {
                    root.smartRect = detected;
                }
            }
        } else {
            root.smartRect = Qt.rect(0, 0, 0, 0);
            root.hoveredWindow = ({ found: false, x: 0, y: 0, width: 0, height: 0, title: "" });
        }
        crosshairCanvas.requestPaint();
    }

    function toggleCaptureMode() {
        if (root.hasConfirmedSelection) return;
        if (root.captureMode === "freeform") {
            setCaptureMode("window");
        } else if (root.captureMode === "window") {
            setCaptureMode("smart");
        } else {
            setCaptureMode("freeform");
        }
    }

    function resetSelection() {
        root.isSelecting = false;
        root.startX = -100;
        root.startY = -100;
        root.currentX = -100;
        root.currentY = -100;
        root.isRightSelecting = false;
        root.rightStartX = -100;
        root.rightStartY = -100;
        root.rightCurrentX = -100;
        root.rightCurrentY = -100;
        root.mouseX = -100;
        root.mouseY = -100;
        root.hasConfirmedSelection = false;
        root.confirmedX = 0;
        root.confirmedY = 0;
        root.confirmedW = 0;
        root.confirmedH = 0;
        root.hasCustomToolbarPos = false;
        root.customToolbarX = 0;
        root.customToolbarY = 0;
        root.isCustomAskMode = false;
        if (customInput) customInput.text = "";
        root.smartRect = Qt.rect(0, 0, 0, 0);
    }

    function commitSelection(x, y, w, h) {
        if (w < 4 || h < 4) {
            root.hasConfirmedSelection = false;
            return;
        }
        root.isSelecting = false;
        root.isRightSelecting = false;
        root.confirmedX = Math.max(0, Math.min(root.width - w, x));
        root.confirmedY = Math.max(0, Math.min(root.height - h, y));
        root.confirmedW = Math.min(root.width - root.confirmedX, w);
        root.confirmedH = Math.min(root.height - root.confirmedY, h);
        root.hasCustomToolbarPos = false;
        root.hasConfirmedSelection = true;
        root.isCustomAskMode = false;
        keyHandler.forceActiveFocus();
    }

    function confirmAndCopy() {
        if (!root.hasConfirmedSelection || root.confirmedW < 4 || root.confirmedH < 4) return;
        AppManager.captureAndCopy(root.confirmedX, root.confirmedY, root.confirmedW, root.confirmedH);
        root.resetSelection();
        root.hide();
    }

    function confirmAndTriggerPrompt(index) {
        if (!root.hasConfirmedSelection || root.confirmedW < 4 || root.confirmedH < 4) return;
        let pList = root.activeImagePrompts;
        if (index >= 0 && index < pList.length) {
            let promptText = pList[index].prompt || "";
            AppManager.captureAndTriggerCustomPrompt(root.confirmedX, root.confirmedY, root.confirmedW, root.confirmedH, promptText, AppManager.autoRun);
        } else {
            AppManager.captureAndTriggerAction(root.confirmedX, root.confirmedY, root.confirmedW, root.confirmedH, index);
        }
        root.resetSelection();
        root.hide();
    }

    function confirmCustomAsk(query) {
        if (!root.hasConfirmedSelection || root.confirmedW < 4 || root.confirmedH < 4) return;
        AppManager.captureAndTriggerCustomPrompt(root.confirmedX, root.confirmedY, root.confirmedW, root.confirmedH, query, true);
        root.resetSelection();
        root.hide();
    }

    function cancelSelection() {
        if (root.isCustomAskMode) {
            root.isCustomAskMode = false;
            return;
        }
        root.resetSelection();
        root.hide();
        AppManager.cancelAction();
    }

    onVisibleChanged: {
        if (!visible) {
            resetSelection();
        }
    }

    function startSnipping() {
        resetSelection();
        root.snapshotTimestamp = AppManager.getSnapshotTimestamp();
        updateMultiScreenGeometry();
        root.show();
        root.raise();
        root.requestActivate();
        keyHandler.forceActiveFocus();
    }

    function openCustomAsk() {
        if (!root.hasConfirmedSelection) return;
        root.isCustomAskMode = true;
        customInput.text = "";
        customInput.forceActiveFocus();
    }

    function submitCustomAsk() {
        let q = customInput.text.trim();
        if (q !== "") {
            root.confirmCustomAsk(q);
        }
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (root.isCustomAskMode) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.submitCustomAsk();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Escape) {
                    root.isCustomAskMode = false;
                    keyHandler.forceActiveFocus();
                    event.accepted = true;
                    return;
                }
                return;
            }

            if (event.key === Qt.Key_Alt || event.key === Qt.Key_Tab) {
                root.toggleCaptureMode();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Escape) {
                root.cancelSelection();
                event.accepted = true;
                return;
            }

            if (root.hasConfirmedSelection) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.confirmAndCopy();
                    event.accepted = true;
                    return;
                }

                // Numeric keys 1 to 9 (top row or numpad)
                let numIdx = -1;
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    numIdx = event.key - Qt.Key_1;
                } else if (event.text >= "1" && event.text <= "9") {
                    numIdx = parseInt(event.text) - 1;
                }

                if (numIdx >= 0) {
                    if (numIdx < root.activeImagePrompts.length) {
                        root.confirmAndTriggerPrompt(numIdx);
                    }
                    event.accepted = true;
                    return;
                }

                // Custom Ask Hotkeys: '0', 'T', '?'
                if (event.key === Qt.Key_0 || event.key === Qt.Key_T || event.key === Qt.Key_Question || event.text === "0" || event.text === "t" || event.text === "T" || event.text === "?") {
                    root.openCustomAsk();
                    event.accepted = true;
                    return;
                }
            }
        }
    }

    // --- GLOBAL TOP-LEVEL WINDOW SHORTCUTS ---
    Shortcut { sequence: "Escape"; context: Qt.WindowShortcut; onActivated: root.cancelSelection() }
    Shortcut { sequence: "Return"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode; context: Qt.WindowShortcut; onActivated: root.confirmAndCopy() }
    Shortcut { sequence: "Enter"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode; context: Qt.WindowShortcut; onActivated: root.confirmAndCopy() }

    Shortcut { sequence: "1"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode && root.activeImagePrompts.length > 0; context: Qt.WindowShortcut; onActivated: root.confirmAndTriggerPrompt(0) }
    Shortcut { sequence: "2"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode && root.activeImagePrompts.length > 1; context: Qt.WindowShortcut; onActivated: root.confirmAndTriggerPrompt(1) }
    Shortcut { sequence: "3"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode && root.activeImagePrompts.length > 2; context: Qt.WindowShortcut; onActivated: root.confirmAndTriggerPrompt(2) }
    Shortcut { sequence: "4"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode && root.activeImagePrompts.length > 3; context: Qt.WindowShortcut; onActivated: root.confirmAndTriggerPrompt(3) }
    Shortcut { sequence: "5"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode && root.activeImagePrompts.length > 4; context: Qt.WindowShortcut; onActivated: root.confirmAndTriggerPrompt(4) }
    Shortcut { sequence: "6"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode && root.activeImagePrompts.length > 5; context: Qt.WindowShortcut; onActivated: root.confirmAndTriggerPrompt(5) }
    Shortcut { sequence: "7"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode && root.activeImagePrompts.length > 6; context: Qt.WindowShortcut; onActivated: root.confirmAndTriggerPrompt(6) }
    Shortcut { sequence: "8"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode && root.activeImagePrompts.length > 7; context: Qt.WindowShortcut; onActivated: root.confirmAndTriggerPrompt(7) }
    Shortcut { sequence: "9"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode && root.activeImagePrompts.length > 8; context: Qt.WindowShortcut; onActivated: root.confirmAndTriggerPrompt(8) }

    Shortcut { sequence: "0"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode; context: Qt.WindowShortcut; onActivated: root.openCustomAsk() }
    Shortcut { sequence: "T"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode; context: Qt.WindowShortcut; onActivated: root.openCustomAsk() }
    Shortcut { sequence: "?"; enabled: root.hasConfirmedSelection && !root.isCustomAskMode; context: Qt.WindowShortcut; onActivated: root.openCustomAsk() }

    // --- OVERLAY ROOT ITEM ---
    Item {
        id: overlayRoot
        anchors.fill: parent

        // 1. Frozen Screen Backdrop (High Precision Zero Flicker)
        Image {
            id: frozenBackdrop
            anchors.fill: parent
            source: root.snapshotTimestamp > 0 ? ("image://snapshot/fullscreen?v=" + root.snapshotTimestamp) : ""
            fillMode: Image.Stretch
            cache: false
            asynchronous: false
        }

        // 2. Translucent Dimming (Darkens unselected parts)
        Item {
            id: dimContainer
            anchors.fill: parent
            property bool active: root.hasConfirmedSelection || root.isAnyDragging

            Rectangle {
                x: 0; y: 0; width: root.width; height: dimContainer.active ? root.maskY : root.height
                color: "#4d0f172a"
            }
            Rectangle {
                visible: dimContainer.active && root.maskH > 0
                x: 0; y: root.maskY + root.maskH; width: root.width; height: Math.max(0, root.height - (root.maskY + root.maskH))
                color: "#4d0f172a"
            }
            Rectangle {
                visible: dimContainer.active && root.maskW > 0 && root.maskH > 0
                x: 0; y: root.maskY; width: root.maskX; height: root.maskH
                color: "#4d0f172a"
            }
            Rectangle {
                visible: dimContainer.active && root.maskW > 0 && root.maskH > 0
                x: root.maskX + root.maskW; y: root.maskY; width: Math.max(0, root.width - (root.maskX + root.maskW)); height: root.maskH
                color: "#4d0f172a"
            }
        }

        // 2.5 Window Snip Mode Highlight Rectangle (Indigo / Accent Blue)
        Rectangle {
            id: windowHighlightRect
            visible: !root.hasConfirmedSelection && !root.isAnyDragging && root.captureMode === "window" && root.hoveredWindow.found && root.hoveredWindow.width > 20 && root.hoveredWindow.height > 20
            x: root.hoveredWindow.x; y: root.hoveredWindow.y; width: root.hoveredWindow.width; height: root.hoveredWindow.height
            color: "#182563eb"; border.color: "#2563eb"; border.width: 2; radius: 4; z: 82

            Rectangle { width: 8; height: 8; radius: 4; x: -4; y: -4; color: "#ffffff"; border.color: "#2563eb"; border.width: 1.8 }
            Rectangle { width: 8; height: 8; radius: 4; x: parent.width - 4; y: -4; color: "#ffffff"; border.color: "#2563eb"; border.width: 1.8 }
            Rectangle { width: 8; height: 8; radius: 4; x: -4; y: parent.height - 4; color: "#ffffff"; border.color: "#2563eb"; border.width: 1.8 }
            Rectangle { width: 8; height: 8; radius: 4; x: parent.width - 4; y: parent.height - 4; color: "#ffffff"; border.color: "#2563eb"; border.width: 1.8 }

            Rectangle {
                anchors.bottom: parent.top; anchors.bottomMargin: 8; anchors.horizontalCenter: parent.horizontalCenter
                width: winBadgeRow.implicitWidth + 20; height: 26; radius: 13; color: "#ffffff"; border.color: "#2563eb"; border.width: 1.2; z: 90
                Rectangle { anchors.fill: parent; anchors.margins: -1; radius: 14; color: "transparent"; border.color: "#200f172a"; border.width: 1; z: -1 }
                Row {
                    id: winBadgeRow; anchors.centerIn: parent; spacing: 6
                    Rectangle { width: 7; height: 7; radius: 3.5; color: "#2563eb"; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: `${root.hoveredWindow.title ? (root.hoveredWindow.title + " | ") : ""}${root.hoveredWindow.width} × ${root.hoveredWindow.height} px | ${AppManager.isThai ? "คลิกเพื่อเลือกหน้าต่างนี้" : "Click to select window"}`
                        font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#1d4ed8"; anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // 3. Smart Element Detection Highlight Box (Purple)
        Rectangle {
            id: smartHighlightRect
            visible: !root.hasConfirmedSelection && !root.isAnyDragging && root.captureMode === "smart" && root.smartRect.width > 4 && root.smartRect.height > 4
            x: root.smartRect.x; y: root.smartRect.y; width: root.smartRect.width; height: root.smartRect.height
            color: "#188b5cf6"; border.color: "#8b5cf6"; border.width: 1.5; z: 80

            Rectangle { width: 7; height: 7; radius: 3.5; x: -3; y: -3; color: "#ffffff"; border.color: "#8b5cf6"; border.width: 1.5 }
            Rectangle { width: 7; height: 7; radius: 3.5; x: parent.width - 4; y: -3; color: "#ffffff"; border.color: "#8b5cf6"; border.width: 1.5 }
            Rectangle { width: 7; height: 7; radius: 3.5; x: -3; y: parent.height - 4; color: "#ffffff"; border.color: "#8b5cf6"; border.width: 1.5 }
            Rectangle { width: 7; height: 7; radius: 3.5; x: parent.width - 4; y: parent.height - 4; color: "#ffffff"; border.color: "#8b5cf6"; border.width: 1.5 }

            Rectangle {
                anchors.bottom: parent.top; anchors.bottomMargin: 6; anchors.horizontalCenter: parent.horizontalCenter
                width: smartBadgeText.implicitWidth + 16; height: 22; radius: 11; color: "#ffffff"; border.color: "#8b5cf6"; border.width: 1
                Text {
                    id: smartBadgeText
                    anchors.centerIn: parent
                    text: `${root.smartRect.width} × ${root.smartRect.height} px | ${AppManager.isThai ? "คลิกเพื่อเลือก" : "Click to select"}`
                    font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; color: "#7c3aed"
                }
            }
        }

        // 4. Right-Click Drag Smart Auto-Fit Selection Rectangle (Cyan)
        Rectangle {
            id: roughSelRect
            visible: !root.hasConfirmedSelection && root.isRightSelecting && root.rightSelW > 0 && root.rightSelH > 0
            x: root.rightSelX; y: root.rightSelY; width: root.rightSelW; height: root.rightSelH
            color: "#1806b6d4"; border.color: "#06b6d4"; border.width: 1.8; z: 88

            Rectangle { width: 8; height: 8; radius: 4; x: -3; y: -3; color: "#ffffff"; border.color: "#06b6d4"; border.width: 1.5 }
            Rectangle { width: 8; height: 8; radius: 4; x: parent.width - 4; y: -3; color: "#ffffff"; border.color: "#06b6d4"; border.width: 1.5 }
            Rectangle { width: 8; height: 8; radius: 4; x: -3; y: parent.height - 4; color: "#ffffff"; border.color: "#06b6d4"; border.width: 1.5 }
            Rectangle { width: 8; height: 8; radius: 4; x: parent.width - 4; y: parent.height - 4; color: "#ffffff"; border.color: "#06b6d4"; border.width: 1.5 }

            Rectangle {
                anchors.bottom: parent.top; anchors.bottomMargin: 6; anchors.horizontalCenter: parent.horizontalCenter
                width: roughBadgeRow.implicitWidth + 18; height: 24; radius: 12; color: "#ffffff"; border.color: "#06b6d4"; border.width: 1.2; z: 90
                Row {
                    id: roughBadgeRow; anchors.centerIn: parent; spacing: 5
                    Rectangle { width: 6; height: 6; radius: 3; color: "#0891b2" }
                    Text {
                        text: AppManager.isThai ? `${root.rightSelW} × ${root.rightSelH} px | ปล่อยเพื่อเดาขอบเขตอัตโนมัติ` : `${root.rightSelW} × ${root.rightSelH} px | Release to Auto-Fit`
                        font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.DemiBold; color: "#0891b2"
                    }
                }
            }
        }

        // 5. Active Drag Freeform Selection Rectangle (Sky Blue)
        Rectangle {
            id: selRect
            visible: !root.hasConfirmedSelection && root.isSelecting && root.selW > 0 && root.selH > 0
            x: root.selX; y: root.selY; width: root.selW; height: root.selH
            color: "#12ffffff"; border.color: "#0284c7"; border.width: 1.5; z: 85
            Rectangle {
                visible: root.selW > 25 && root.selH > 25
                anchors.bottom: parent.top; anchors.bottomMargin: 6; anchors.horizontalCenter: parent.horizontalCenter
                width: dragBadgeText.implicitWidth + 16; height: 22; radius: 11; color: "#ffffff"; border.color: "#0284c7"; border.width: 1
                Text {
                    id: dragBadgeText
                    anchors.centerIn: parent
                    text: `${root.selW} × ${root.selH} px`
                    font.family: "Fira Code, Consolas, monospace"; font.pixelSize: 10; font.weight: Font.DemiBold; color: "#0284c7"
                }
            }
        }

        // 6. CONFIRMED INTERACTIVE SELECTION BOX
        Rectangle {
            id: confirmedBox
            visible: root.hasConfirmedSelection && root.confirmedW > 3 && root.confirmedH > 3
            x: root.confirmedX
            y: root.confirmedY
            width: root.confirmedW
            height: root.confirmedH
            color: "#0838bdf8"
            border.color: "#0284c7"
            border.width: 2
            z: 90

            property real dragStartRootX: 0
            property real dragStartRootY: 0
            property int dragOrigX1: 0
            property int dragOrigY1: 0
            property int dragOrigX2: 0
            property int dragOrigY2: 0
            property int dragOrigW: 0
            property int dragOrigH: 0

            function initDrag(startRx, startRy) {
                dragStartRootX = startRx;
                dragStartRootY = startRy;
                dragOrigX1 = root.confirmedX;
                dragOrigY1 = root.confirmedY;
                dragOrigX2 = root.confirmedX + root.confirmedW;
                dragOrigY2 = root.confirmedY + root.confirmedH;
                dragOrigW = root.confirmedW;
                dragOrigH = root.confirmedH;
            }

            // Center Move Body Area
            MouseArea {
                id: bodyArea
                anchors.fill: parent
                anchors.margins: 10
                cursorShape: Qt.SizeAllCursor
                z: 91
                onPressed: function(m) {
                    let pos = bodyArea.mapToItem(overlayRoot, m.x, m.y);
                    confirmedBox.initDrag(pos.x, pos.y);
                }
                onPositionChanged: function(m) {
                    if (pressed) {
                        let pos = bodyArea.mapToItem(overlayRoot, m.x, m.y);
                        let dx = pos.x - confirmedBox.dragStartRootX;
                        let dy = pos.y - confirmedBox.dragStartRootY;
                        root.confirmedX = Math.max(0, Math.min(root.width - confirmedBox.dragOrigW, confirmedBox.dragOrigX1 + dx));
                        root.confirmedY = Math.max(0, Math.min(root.height - confirmedBox.dragOrigH, confirmedBox.dragOrigY1 + dy));
                    }
                }
                onDoubleClicked: { root.confirmAndCopy(); }
            }

            // Top Edge Grab Strip
            MouseArea {
                id: topEdgeArea
                x: 12; y: -6; width: Math.max(1, parent.width - 24); height: 12
                z: 92
                cursorShape: Qt.SizeVerCursor
                onPressed: function(m) { let pos = topEdgeArea.mapToItem(overlayRoot, m.x, m.y); confirmedBox.initDrag(pos.x, pos.y); }
                onPositionChanged: function(m) {
                    if (pressed) {
                        let pos = topEdgeArea.mapToItem(overlayRoot, m.x, m.y);
                        let cy = Math.max(0, Math.min(root.height, pos.y));
                        root.confirmedY = Math.min(confirmedBox.dragOrigY2, cy);
                        root.confirmedH = Math.max(4, Math.abs(confirmedBox.dragOrigY2 - cy));
                    }
                }
            }

            // Bottom Edge Grab Strip
            MouseArea {
                id: bottomEdgeArea
                x: 12; y: parent.height - 6; width: Math.max(1, parent.width - 24); height: 12
                z: 92
                cursorShape: Qt.SizeVerCursor
                onPressed: function(m) { let pos = bottomEdgeArea.mapToItem(overlayRoot, m.x, m.y); confirmedBox.initDrag(pos.x, pos.y); }
                onPositionChanged: function(m) {
                    if (pressed) {
                        let pos = bottomEdgeArea.mapToItem(overlayRoot, m.x, m.y);
                        let cy = Math.max(0, Math.min(root.height, pos.y));
                        root.confirmedY = Math.min(confirmedBox.dragOrigY1, cy);
                        root.confirmedH = Math.max(4, Math.abs(confirmedBox.dragOrigY1 - cy));
                    }
                }
            }

            // Left Edge Grab Strip
            MouseArea {
                id: leftEdgeArea
                x: -6; y: 12; width: 12; height: Math.max(1, parent.height - 24)
                z: 92
                cursorShape: Qt.SizeHorCursor
                onPressed: function(m) { let pos = leftEdgeArea.mapToItem(overlayRoot, m.x, m.y); confirmedBox.initDrag(pos.x, pos.y); }
                onPositionChanged: function(m) {
                    if (pressed) {
                        let pos = leftEdgeArea.mapToItem(overlayRoot, m.x, m.y);
                        let cx = Math.max(0, Math.min(root.width, pos.x));
                        root.confirmedX = Math.min(confirmedBox.dragOrigX2, cx);
                        root.confirmedW = Math.max(4, Math.abs(confirmedBox.dragOrigX2 - cx));
                    }
                }
            }

            // Right Edge Grab Strip
            MouseArea {
                id: rightEdgeArea
                x: parent.width - 6; y: 12; width: 12; height: Math.max(1, parent.height - 24)
                z: 92
                cursorShape: Qt.SizeHorCursor
                onPressed: function(m) { let pos = rightEdgeArea.mapToItem(overlayRoot, m.x, m.y); confirmedBox.initDrag(pos.x, pos.y); }
                onPositionChanged: function(m) {
                    if (pressed) {
                        let pos = rightEdgeArea.mapToItem(overlayRoot, m.x, m.y);
                        let cx = Math.max(0, Math.min(root.width, pos.x));
                        root.confirmedX = Math.min(confirmedBox.dragOrigX1, cx);
                        root.confirmedW = Math.max(4, Math.abs(confirmedBox.dragOrigX1 - cx));
                    }
                }
            }

            // 1. Top-Left Corner Handle
            Item {
                x: -12; y: -12; width: 24; height: 24; z: 95
                Rectangle { anchors.centerIn: parent; width: tlArea.containsMouse || tlArea.pressed ? 10 : 8; height: width; radius: width / 2; color: "#ffffff"; border.color: "#0284c7"; border.width: 1.8 }
                MouseArea {
                    id: tlArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.SizeFDiagCursor
                    onPressed: function(m) { let pos = tlArea.mapToItem(overlayRoot, m.x, m.y); confirmedBox.initDrag(pos.x, pos.y); }
                    onPositionChanged: function(m) {
                        if (pressed) {
                            let pos = tlArea.mapToItem(overlayRoot, m.x, m.y);
                            let cx = Math.max(0, Math.min(root.width, pos.x));
                            let cy = Math.max(0, Math.min(root.height, pos.y));
                            root.confirmedX = Math.min(confirmedBox.dragOrigX2, cx);
                            root.confirmedY = Math.min(confirmedBox.dragOrigY2, cy);
                            root.confirmedW = Math.max(4, Math.abs(confirmedBox.dragOrigX2 - cx));
                            root.confirmedH = Math.max(4, Math.abs(confirmedBox.dragOrigY2 - cy));
                        }
                    }
                }
            }

            // 2. Top-Center Handle
            Item {
                x: parent.width / 2 - 12; y: -12; width: 24; height: 24; z: 95
                Rectangle { anchors.centerIn: parent; width: tcArea.containsMouse || tcArea.pressed ? 10 : 8; height: width; radius: width / 2; color: "#ffffff"; border.color: "#0284c7"; border.width: 1.8 }
                MouseArea {
                    id: tcArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.SizeVerCursor
                    onPressed: function(m) { let pos = tcArea.mapToItem(overlayRoot, m.x, m.y); confirmedBox.initDrag(pos.x, pos.y); }
                    onPositionChanged: function(m) {
                        if (pressed) {
                            let pos = tcArea.mapToItem(overlayRoot, m.x, m.y);
                            let cy = Math.max(0, Math.min(root.height, pos.y));
                            root.confirmedY = Math.min(confirmedBox.dragOrigY2, cy);
                            root.confirmedH = Math.max(4, Math.abs(confirmedBox.dragOrigY2 - cy));
                        }
                    }
                }
            }

            // 3. Top-Right Corner Handle
            Item {
                x: parent.width - 12; y: -12; width: 24; height: 24; z: 95
                Rectangle { anchors.centerIn: parent; width: trArea.containsMouse || trArea.pressed ? 10 : 8; height: width; radius: width / 2; color: "#ffffff"; border.color: "#0284c7"; border.width: 1.8 }
                MouseArea {
                    id: trArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.SizeBDiagCursor
                    onPressed: function(m) { let pos = trArea.mapToItem(overlayRoot, m.x, m.y); confirmedBox.initDrag(pos.x, pos.y); }
                    onPositionChanged: function(m) {
                        if (pressed) {
                            let pos = trArea.mapToItem(overlayRoot, m.x, m.y);
                            let cx = Math.max(0, Math.min(root.width, pos.x));
                            let cy = Math.max(0, Math.min(root.height, pos.y));
                            root.confirmedX = Math.min(confirmedBox.dragOrigX1, cx);
                            root.confirmedY = Math.min(confirmedBox.dragOrigY2, cy);
                            root.confirmedW = Math.max(4, Math.abs(confirmedBox.dragOrigX1 - cx));
                            root.confirmedH = Math.max(4, Math.abs(confirmedBox.dragOrigY2 - cy));
                        }
                    }
                }
            }

            // 4. Middle-Right Handle
            Item {
                x: parent.width - 12; y: parent.height / 2 - 12; width: 24; height: 24; z: 95
                Rectangle { anchors.centerIn: parent; width: mrArea.containsMouse || mrArea.pressed ? 10 : 8; height: width; radius: width / 2; color: "#ffffff"; border.color: "#0284c7"; border.width: 1.8 }
                MouseArea {
                    id: mrArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.SizeHorCursor
                    onPressed: function(m) { let pos = mrArea.mapToItem(overlayRoot, m.x, m.y); confirmedBox.initDrag(pos.x, pos.y); }
                    onPositionChanged: function(m) {
                        if (pressed) {
                            let pos = mrArea.mapToItem(overlayRoot, m.x, m.y);
                            let cx = Math.max(0, Math.min(root.width, pos.x));
                            root.confirmedX = Math.min(confirmedBox.dragOrigX1, cx);
                            root.confirmedW = Math.max(4, Math.abs(confirmedBox.dragOrigX1 - cx));
                        }
                    }
                }
            }

            // 5. Bottom-Right Corner Handle
            Item {
                x: parent.width - 12; y: parent.height - 12; width: 24; height: 24; z: 95
                Rectangle { anchors.centerIn: parent; width: brArea.containsMouse || brArea.pressed ? 10 : 8; height: width; radius: width / 2; color: "#ffffff"; border.color: "#0284c7"; border.width: 1.8 }
                MouseArea {
                    id: brArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.SizeFDiagCursor
                    onPressed: function(m) { let pos = brArea.mapToItem(overlayRoot, m.x, m.y); confirmedBox.initDrag(pos.x, pos.y); }
                    onPositionChanged: function(m) {
                        if (pressed) {
                            let pos = brArea.mapToItem(overlayRoot, m.x, m.y);
                            let cx = Math.max(0, Math.min(root.width, pos.x));
                            let cy = Math.max(0, Math.min(root.height, pos.y));
                            root.confirmedX = Math.min(confirmedBox.dragOrigX1, cx);
                            root.confirmedY = Math.min(confirmedBox.dragOrigY1, cy);
                            root.confirmedW = Math.max(4, Math.abs(confirmedBox.dragOrigX1 - cx));
                            root.confirmedH = Math.max(4, Math.abs(confirmedBox.dragOrigY1 - cy));
                        }
                    }
                }
            }

            // 6. Bottom-Center Handle
            Item {
                x: parent.width / 2 - 12; y: parent.height - 12; width: 24; height: 24; z: 95
                Rectangle { anchors.centerIn: parent; width: bcArea.containsMouse || bcArea.pressed ? 10 : 8; height: width; radius: width / 2; color: "#ffffff"; border.color: "#0284c7"; border.width: 1.8 }
                MouseArea {
                    id: bcArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.SizeVerCursor
                    onPressed: function(m) { let pos = bcArea.mapToItem(overlayRoot, m.x, m.y); confirmedBox.initDrag(pos.x, pos.y); }
                    onPositionChanged: function(m) {
                        if (pressed) {
                            let pos = bcArea.mapToItem(overlayRoot, m.x, m.y);
                            let cy = Math.max(0, Math.min(root.height, pos.y));
                            root.confirmedY = Math.min(confirmedBox.dragOrigY1, cy);
                            root.confirmedH = Math.max(4, Math.abs(confirmedBox.dragOrigY1 - cy));
                        }
                    }
                }
            }

            // 7. Bottom-Left Corner Handle
            Item {
                x: -12; y: parent.height - 12; width: 24; height: 24; z: 95
                Rectangle { anchors.centerIn: parent; width: blArea.containsMouse || blArea.pressed ? 10 : 8; height: width; radius: width / 2; color: "#ffffff"; border.color: "#0284c7"; border.width: 1.8 }
                MouseArea {
                    id: blArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.SizeBDiagCursor
                    onPressed: function(m) { let pos = blArea.mapToItem(overlayRoot, m.x, m.y); confirmedBox.initDrag(pos.x, pos.y); }
                    onPositionChanged: function(m) {
                        if (pressed) {
                            let pos = blArea.mapToItem(overlayRoot, m.x, m.y);
                            let cx = Math.max(0, Math.min(root.width, pos.x));
                            let cy = Math.max(0, Math.min(root.height, pos.y));
                            root.confirmedX = Math.min(confirmedBox.dragOrigX2, cx);
                            root.confirmedY = Math.min(confirmedBox.dragOrigY1, cy);
                            root.confirmedW = Math.max(4, Math.abs(confirmedBox.dragOrigX2 - cx));
                            root.confirmedH = Math.max(4, Math.abs(confirmedBox.dragOrigY1 - cy));
                        }
                    }
                }
            }

            // 8. Middle-Left Handle
            Item {
                x: -12; y: parent.height / 2 - 12; width: 24; height: 24; z: 95
                Rectangle { anchors.centerIn: parent; width: mlArea.containsMouse || mlArea.pressed ? 10 : 8; height: width; radius: width / 2; color: "#ffffff"; border.color: "#0284c7"; border.width: 1.8 }
                MouseArea {
                    id: mlArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.SizeHorCursor
                    onPressed: function(m) { let pos = mlArea.mapToItem(overlayRoot, m.x, m.y); confirmedBox.initDrag(pos.x, pos.y); }
                    onPositionChanged: function(m) {
                        if (pressed) {
                            let pos = mlArea.mapToItem(overlayRoot, m.x, m.y);
                            let cx = Math.max(0, Math.min(root.width, pos.x));
                            root.confirmedX = Math.min(confirmedBox.dragOrigX2, cx);
                            root.confirmedW = Math.max(4, Math.abs(confirmedBox.dragOrigX2 - cx));
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.top; anchors.bottomMargin: 6; anchors.horizontalCenter: parent.horizontalCenter
                width: confirmedBadgeText.implicitWidth + 18; height: 24; radius: 12; color: "#ffffff"; border.color: "#0284c7"; border.width: 1.2; z: 95
                Rectangle { anchors.fill: parent; anchors.margins: -1; radius: 13; color: "transparent"; border.color: "#200f172a"; border.width: 1; z: -1 }
                Text {
                    id: confirmedBadgeText; anchors.centerIn: parent; text: `${root.confirmedW} × ${root.confirmedH} px`; font.family: "Fira Code, Consolas, monospace"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#0284c7"
                }
            }
        }

        // 7. ATTACHED UNIFIED FLOATING ACTION BAR
        Rectangle {
            id: floatingActionBar
            visible: root.hasConfirmedSelection && root.confirmedW > 3 && root.confirmedH > 3
            z: 95

            readonly property real defaultX: Math.max(12, Math.min(root.width - width - 12, root.confirmedX + (root.confirmedW - width) / 2))
            readonly property real defaultY: {
                let belowY = root.confirmedY + root.confirmedH + 10;
                if (belowY + height + 10 <= root.height) {
                    return belowY;
                }
                let aboveY = root.confirmedY - height - 36;
                if (aboveY >= 10) {
                    return aboveY;
                }
                return Math.max(10, root.confirmedY + 10);
            }

            x: root.hasCustomToolbarPos ? root.customToolbarX : defaultX
            y: root.hasCustomToolbarPos ? root.customToolbarY : defaultY
            width: root.isCustomAskMode ? 460 : (buttonRow.implicitWidth + 16)
            height: root.barHeight
            radius: 8
            color: "#ffffff"
            border.color: "#e2e8f0"
            border.width: 1

            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Rectangle { anchors.fill: parent; anchors.margins: -1; radius: 9; color: "transparent"; border.color: "#180f172a"; border.width: 1; z: -1 }

            Row {
                id: buttonRow
                anchors.centerIn: parent
                spacing: 4
                visible: !root.isCustomAskMode
                opacity: root.isCustomAskMode ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: 100 } }

                // Drag handle (Moves ONLY the toolbar, leaving crop box in place)
                Rectangle {
                    width: 18
                    height: root.btnHeight
                    radius: 4
                    color: dragMouse.containsMouse ? "#edf2f7" : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

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
                                color: dragMouse.containsMouse ? "#1e293b" : "#94a3b8"
                            }
                        }
                    }

                    MouseArea {
                        id: dragMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeAllCursor

                        property real startMouseX: 0
                        property real startMouseY: 0
                        property real startBarX: 0
                        property real startBarY: 0

                        onPressed: function(m) {
                            let pos = dragMouse.mapToItem(overlayRoot, m.x, m.y);
                            startMouseX = pos.x;
                            startMouseY = pos.y;
                            startBarX = floatingActionBar.x;
                            startBarY = floatingActionBar.y;
                        }

                        onPositionChanged: function(m) {
                            if (pressed) {
                                let pos = dragMouse.mapToItem(overlayRoot, m.x, m.y);
                                let dx = pos.x - startMouseX;
                                let dy = pos.y - startMouseY;
                                root.hasCustomToolbarPos = true;
                                root.customToolbarX = Math.max(10, Math.min(root.width - floatingActionBar.width - 10, startBarX + dx));
                                root.customToolbarY = Math.max(10, Math.min(root.height - floatingActionBar.height - 10, startBarY + dy));
                            }
                        }
                    }
                }

                Repeater {
                    model: root.activeImagePrompts
                    delegate: Rectangle {
                        id: btnCard; width: btnContent.implicitWidth + 14; height: root.btnHeight; radius: 6; color: btnMouse.containsMouse ? "#f1f5f9" : "transparent"; border.color: btnMouse.containsMouse ? "#cbd5e1" : "transparent"; border.width: 1; anchors.verticalCenter: parent.verticalCenter; scale: btnMouse.pressed ? 0.96 : (btnMouse.containsMouse ? 1.02 : 1.0); Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                        Row { id: btnContent; anchors.centerIn: parent; spacing: 6; Rectangle { width: Math.max(root.badgeSize, badgeTextObj.implicitWidth + 6); height: root.badgeSize; radius: 4; color: "#f1f5f9"; border.color: "#e2e8f0"; border.width: 1; anchors.verticalCenter: parent.verticalCenter; Text { id: badgeTextObj; anchors.centerIn: parent; text: modelData.badge ? modelData.badge : String(index + 1); font.family: Theme.fontFamily; font.pixelSize: root.badgeFontSize; font.weight: Font.DemiBold; color: "#64748b" } } Text { text: root.getShortLabel(modelData.label); font.family: Theme.fontFamily; font.pixelSize: root.fontSize; font.weight: Font.Normal; color: "#1e293b"; anchors.verticalCenter: parent.verticalCenter } }
                        MouseArea { id: btnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.confirmAndTriggerPrompt(index); } }
                    }
                }
                Rectangle {
                    id: customAskBtn
                    width: customAskContent.implicitWidth + 14
                    height: root.btnHeight
                    radius: 6
                    color: customAskMouse.containsMouse ? "#f1f5f9" : "transparent"
                    border.color: customAskMouse.containsMouse ? "#cbd5e1" : "transparent"
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    scale: customAskMouse.pressed ? 0.96 : (customAskMouse.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

                    Row {
                        id: customAskContent
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: Math.max(root.badgeSize, customBadgeText.implicitWidth + 6)
                            height: root.badgeSize
                            radius: 4
                            color: "#f1f5f9"
                            border.color: "#e2e8f0"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: customBadgeText
                                anchors.centerIn: parent
                                text: "?"
                                font.family: Theme.fontFamily
                                font.pixelSize: root.badgeFontSize
                                font.weight: Font.DemiBold
                                color: "#64748b"
                            }
                        }

                        Text {
                            text: AppManager.isThai ? "ถามเอง" : "Custom Ask"
                            font.family: Theme.fontFamily
                            font.pixelSize: root.fontSize
                            font.weight: Font.Normal
                            color: "#1e293b"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: customAskMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.openCustomAsk();
                        }
                    }
                }

                Rectangle {
                    id: copyBtn
                    width: copyContent.implicitWidth + 14
                    height: root.btnHeight
                    radius: 6
                    color: copyMouse.containsMouse ? "#f1f5f9" : "transparent"
                    border.color: copyMouse.containsMouse ? "#cbd5e1" : "transparent"
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    scale: copyMouse.pressed ? 0.96 : (copyMouse.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

                    Row {
                        id: copyContent
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: Math.max(root.badgeSize, copyBadgeText.implicitWidth + 6)
                            height: root.badgeSize
                            radius: 4
                            color: "#f1f5f9"
                            border.color: "#e2e8f0"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: copyBadgeText
                                anchors.centerIn: parent
                                text: "↵"
                                font.family: Theme.fontFamily
                                font.pixelSize: root.badgeFontSize
                                font.weight: Font.DemiBold
                                color: "#64748b"
                            }
                        }

                        Text {
                            text: AppManager.isThai ? "คัดลอกรูป" : "Copy Image"
                            font.family: Theme.fontFamily
                            font.pixelSize: root.fontSize
                            font.weight: Font.Normal
                            color: "#1e293b"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.confirmAndCopy();
                        }
                    }
                }
                Rectangle {
                    id: cancelBtn; width: cancelContent.implicitWidth + 14; height: root.btnHeight; radius: 6; color: cancelMouse.containsMouse ? "#fee2e2" : "transparent"; border.color: cancelMouse.containsMouse ? "#fca5a5" : "transparent"; border.width: 1; anchors.verticalCenter: parent.verticalCenter; scale: cancelMouse.pressed ? 0.96 : (cancelMouse.containsMouse ? 1.02 : 1.0); Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                    Row { id: cancelContent; anchors.centerIn: parent; spacing: 6; Rectangle { width: Math.max(root.badgeSize, cancelBadgeText.implicitWidth + 6); height: root.badgeSize; radius: 4; color: "#f1f5f9"; border.color: "#e2e8f0"; border.width: 1; anchors.verticalCenter: parent.verticalCenter; Text { id: cancelBadgeText; anchors.centerIn: parent; text: "Esc"; font.family: Theme.fontFamily; font.pixelSize: root.badgeFontSize; font.weight: Font.Normal; color: cancelMouse.containsMouse ? "#ef4444" : "#64748b" } } Text { text: AppManager.isThai ? "ยกเลิก" : "Cancel"; font.family: Theme.fontFamily; font.pixelSize: root.fontSize; font.weight: Font.Normal; color: cancelMouse.containsMouse ? "#ef4444" : "#1e293b"; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { id: cancelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.cancelSelection(); } }
                }
            }
            Row {
                id: customInputRow; anchors.fill: parent; anchors.margins: 4; spacing: 6; visible: root.isCustomAskMode; opacity: root.isCustomAskMode ? 1.0 : 0.0; Behavior on opacity { NumberAnimation { duration: 100 } }
                Rectangle {
                    width: 14
                    height: parent.height
                    radius: 4
                    color: customDragMouse.containsMouse ? "#edf2f7" : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Grid { anchors.centerIn: parent; columns: 2; spacing: 2.5; Repeater { model: 6; Rectangle { width: 2.5; height: 2.5; radius: 1.25; color: customDragMouse.containsMouse ? "#1e293b" : "#94a3b8" } } }

                    MouseArea {
                        id: customDragMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeAllCursor

                        property real startMouseX: 0
                        property real startMouseY: 0
                        property real startBarX: 0
                        property real startBarY: 0

                        onPressed: function(m) {
                            let pos = customDragMouse.mapToItem(overlayRoot, m.x, m.y);
                            startMouseX = pos.x;
                            startMouseY = pos.y;
                            startBarX = floatingActionBar.x;
                            startBarY = floatingActionBar.y;
                        }

                        onPositionChanged: function(m) {
                            if (pressed) {
                                let pos = customDragMouse.mapToItem(overlayRoot, m.x, m.y);
                                let dx = pos.x - startMouseX;
                                let dy = pos.y - startMouseY;
                                root.hasCustomToolbarPos = true;
                                root.customToolbarX = Math.max(10, Math.min(root.width - floatingActionBar.width - 10, startBarX + dx));
                                root.customToolbarY = Math.max(10, Math.min(root.height - floatingActionBar.height - 10, startBarY + dy));
                            }
                        }
                    }
                }
                Rectangle { width: 26; height: parent.height; radius: 6; color: backMouse.containsMouse ? "#f1f5f9" : "transparent"; anchors.verticalCenter: parent.verticalCenter; Text { anchors.centerIn: parent; text: "←"; font.pixelSize: 12; font.weight: Font.Normal; color: "#64748b" } MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.isCustomAskMode = false; keyHandler.forceActiveFocus(); } } }
                Rectangle {
                    width: parent.width - 14 - 26 - sendBtn.width - 24; height: parent.height; radius: 6; color: "#f8fafc"; border.color: customInput.activeFocus ? "#2563eb" : "#cbd5e1"; border.width: 1
                    TextInput {
                        id: customInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: root.fontSize
                        color: "#0f172a"
                        selectByMouse: true
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: !customInput.text && !customInput.activeFocus
                            text: AppManager.isThai ? "พิมพ์คำถามของคุณที่นี่..." : "Ask Gemini about this screenshot..."
                            font.family: Theme.fontFamily
                            font.pixelSize: root.fontSize
                            color: "#94a3b8"
                        }

                        onAccepted: {
                            root.submitCustomAsk();
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.submitCustomAsk();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.isCustomAskMode = false;
                                keyHandler.forceActiveFocus();
                                event.accepted = true;
                            }
                        }
                    }
                }
                Rectangle {
                    id: sendBtn; width: sendContent.implicitWidth + 14; height: parent.height; radius: 6; color: sendMouse.containsMouse ? "#1d4ed8" : "#2563eb"; anchors.verticalCenter: parent.verticalCenter; scale: sendMouse.pressed ? 0.96 : (sendMouse.containsMouse ? 1.02 : 1.0); Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                    Row { id: sendContent; anchors.centerIn: parent; spacing: 4; Text { text: AppManager.isThai ? "ส่ง" : "Send"; font.family: Theme.fontFamily; font.pixelSize: root.fontSize; font.weight: Font.Medium; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter } Text { text: "↵"; font.pixelSize: 11; color: "#93c5fd"; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { id: sendMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.submitCustomAsk(); } }
                }
            }
        }

        // 8. Top Snip Mode Hint Bar
        Rectangle {
            id: topHint
            visible: !root.hasConfirmedSelection && !root.isAnyDragging
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            width: hintRow.implicitWidth + 24
            height: 38
            radius: 19
            color: "#ffffff"
            border.color: "#e2e8f0"
            border.width: 1
            z: 95
            Rectangle { anchors.fill: parent; anchors.margins: -1; radius: 20; color: "transparent"; border.color: "#180f172a"; border.width: 1; z: -1 }
            Row {
                id: hintRow; anchors.centerIn: parent; spacing: 6
                Rectangle {
                    width: freeformPillRow.implicitWidth + 16; height: 26; radius: 13; color: root.captureMode === "freeform" ? "#e0f2fe" : "#ffffff"; border.color: root.captureMode === "freeform" ? "#0284c7" : "#e2e8f0"; border.width: 1; anchors.verticalCenter: parent.verticalCenter
                    Row { id: freeformPillRow; anchors.centerIn: parent; spacing: 4; Rectangle { width: 6; height: 6; radius: 3; color: root.captureMode === "freeform" ? "#0284c7" : "#94a3b8"; anchors.verticalCenter: parent.verticalCenter } Text { text: AppManager.isThai ? "ลากเลือกพื้นที่" : "Area Snip"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: root.captureMode === "freeform" ? Font.Bold : Font.Medium; color: root.captureMode === "freeform" ? "#0369a1" : "#64748b"; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.setCaptureMode("freeform"); } }
                }
                Rectangle {
                    width: windowPillRow.implicitWidth + 16; height: 26; radius: 13; color: root.captureMode === "window" ? "#dbeafe" : "#ffffff"; border.color: root.captureMode === "window" ? "#2563eb" : "#e2e8f0"; border.width: 1; anchors.verticalCenter: parent.verticalCenter
                    Row { id: windowPillRow; anchors.centerIn: parent; spacing: 4; Rectangle { width: 6; height: 6; radius: 3; color: root.captureMode === "window" ? "#2563eb" : "#94a3b8"; anchors.verticalCenter: parent.verticalCenter } Text { text: AppManager.isThai ? "แคปหน้าต่างแอพ" : "Window Snip"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: root.captureMode === "window" ? Font.Bold : Font.Medium; color: root.captureMode === "window" ? "#1d4ed8" : "#64748b"; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.setCaptureMode("window"); } }
                }
                Rectangle {
                    width: smartPillRow.implicitWidth + 16; height: 26; radius: 13; color: root.captureMode === "smart" ? "#ede9fe" : "#ffffff"; border.color: root.captureMode === "smart" ? "#8b5cf6" : "#e2e8f0"; border.width: 1; anchors.verticalCenter: parent.verticalCenter
                    Row { id: smartPillRow; anchors.centerIn: parent; spacing: 4; Rectangle { width: 6; height: 6; radius: 3; color: root.captureMode === "smart" ? "#8b5cf6" : "#94a3b8"; anchors.verticalCenter: parent.verticalCenter } Text { text: AppManager.isThai ? "ตรวจจับโครงสร้าง" : "Smart Detect"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: root.captureMode === "smart" ? Font.Bold : Font.Medium; color: root.captureMode === "smart" ? "#6d28d9" : "#64748b"; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.setCaptureMode("smart"); } }
                }
                Rectangle { width: 1; height: 16; color: "#e2e8f0"; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.captureMode === "window" ? (AppManager.isThai ? "คลิกที่หน้าต่างเพื่อเลือก | [Alt/Tab] สลับโหมด | [Esc] ยกเลิก" : "Click window to snap | [Alt/Tab] Switch mode | [Esc] Cancel") :
                          (root.captureMode === "smart" ? (AppManager.isThai ? "คลิกโครงสร้างเพื่อเลือก | [Alt/Tab] สลับโหมด | [Esc] ยกเลิก" : "Click element to snap | [Alt/Tab] Switch mode | [Esc] Cancel") :
                          (AppManager.isThai ? "ลากเพื่อครอบตัด | [Alt/Tab] สลับโหมด | [Esc] ยกเลิก" : "Drag to crop | [Alt/Tab] Switch mode | [Esc] Cancel"))
                    font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Normal; color: "#64748b"
                }
            }
        }

        // 9. Precision Crosshair Cursor Canvas
        Canvas {
            id: crosshairCanvas
            anchors.fill: parent
            visible: root.mouseX > 0 && root.mouseY > 0 && !root.hasConfirmedSelection
            z: 99
            onPaint: {
                let ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                if (root.mouseX <= 0 || root.mouseY <= 0) return;
                let mx = root.mouseX; let my = root.mouseY; let size = 12; let gap = 4;
                ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 1.5; ctx.beginPath();
                ctx.moveTo(mx - size, my); ctx.lineTo(mx - gap, my); ctx.moveTo(mx + gap, my); ctx.lineTo(mx + size, my); ctx.moveTo(mx, my - size); ctx.lineTo(mx, my - gap); ctx.moveTo(mx, my + gap); ctx.lineTo(mx, my + size); ctx.stroke();
                ctx.beginPath(); ctx.arc(mx, my, 2, 0, Math.PI * 2); ctx.fillStyle = root.isRightSelecting ? "#06b6d4" : (root.captureMode === "window" ? "#2563eb" : (root.captureMode === "smart" ? "#8b5cf6" : "#0284c7")); ctx.fill();
            }
        }

        // 10. Background Mouse Area
        MouseArea {
            id: bgMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.hasConfirmedSelection ? Qt.ArrowCursor : (root.captureMode === "window" && root.hoveredWindow.found ? Qt.PointingHandCursor : Qt.BlankCursor)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            z: 10

            onPressed: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (!root.hasConfirmedSelection && root.captureMode === "window" && root.hoveredWindow.found && root.hoveredWindow.width > 20 && root.hoveredWindow.height > 20) {
                        root.commitSelection(root.hoveredWindow.x, root.hoveredWindow.y, root.hoveredWindow.width, root.hoveredWindow.height);
                        return;
                    }
                    if (!root.hasConfirmedSelection && root.captureMode === "smart" && root.smartRect.width > 4 && root.smartRect.height > 4) {
                        root.commitSelection(root.smartRect.x, root.smartRect.y, root.smartRect.width, root.smartRect.height);
                        return;
                    }
                    root.hasConfirmedSelection = false;
                    root.startX = mouse.x; root.startY = mouse.y; root.currentX = mouse.x; root.currentY = mouse.y; root.mouseX = mouse.x; root.mouseY = mouse.y; root.isSelecting = true;
                    crosshairCanvas.requestPaint();
                } else if (mouse.button === Qt.RightButton) {
                    root.hasConfirmedSelection = false;
                    root.rightStartX = mouse.x; root.rightStartY = mouse.y; root.rightCurrentX = mouse.x; root.rightCurrentY = mouse.y; root.mouseX = mouse.x; root.mouseY = mouse.y; root.isRightSelecting = true;
                    crosshairCanvas.requestPaint();
                }
            }
            onPositionChanged: function(mouse) {
                root.mouseX = mouse.x; root.mouseY = mouse.y;
                if (root.isSelecting) { root.currentX = mouse.x; root.currentY = mouse.y; }
                else if (root.isRightSelecting) { root.rightCurrentX = mouse.x; root.rightCurrentY = mouse.y; }
                else if (!root.hasConfirmedSelection && root.captureMode === "window") {
                    let win = AppManager.detectWindowAt(mouse.x, mouse.y);
                    if (win && win.found) {
                        root.hoveredWindow = win;
                    } else {
                        root.hoveredWindow = ({ found: false, x: 0, y: 0, width: 0, height: 0, title: "" });
                    }
                }
                else if (!root.hasConfirmedSelection && root.captureMode === "smart") {
                    let detected = AppManager.detectElementBounds(mouse.x, mouse.y);
                    if (detected && detected.width > 4 && detected.height > 4) { root.smartRect = detected; }
                }
                crosshairCanvas.requestPaint();
            }
            onReleased: function(mouse) {
                if (root.isSelecting && mouse.button === Qt.LeftButton) {
                    root.currentX = mouse.x;
                    root.currentY = mouse.y;
                    if (root.selW > 4 && root.selH > 4) {
                        root.commitSelection(root.selX, root.selY, root.selW, root.selH);
                    } else {
                        root.isSelecting = false;
                    }
                } else if (root.isRightSelecting && mouse.button === Qt.RightButton) {
                    root.rightCurrentX = mouse.x;
                    root.rightCurrentY = mouse.y;
                    if (root.rightSelW > 8 && root.rightSelH > 8) {
                        let fitted = AppManager.autoFitElementBounds(root.rightSelX, root.rightSelY, root.rightSelW, root.rightSelH);
                        if (fitted && fitted.width > 8 && fitted.height > 8) {
                            root.commitSelection(fitted.x, fitted.y, fitted.width, fitted.height);
                        } else {
                            root.commitSelection(root.rightSelX, root.rightSelY, root.rightSelW, root.rightSelH);
                        }
                    } else {
                        root.isRightSelecting = false;
                    }
                }
            }

            onExited: {
                root.mouseX = -100;
                root.mouseY = -100;
                crosshairCanvas.requestPaint();
            }
        }
    }
}

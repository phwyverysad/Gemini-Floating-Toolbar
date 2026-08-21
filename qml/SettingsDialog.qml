import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "components"

Window {
    id: root

    flags: Qt.Dialog | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    visible: false

    // Locked Window Dimensions - Compact & Clean
    width: 636
    height: 756
    minimumWidth: 636
    maximumWidth: 636
    minimumHeight: 756
    maximumHeight: 756

    property string currentLang: "th"
    property string currentTheme: "light"
    property string currentPlacement: "auto"
    property int currentToolbarHeight: 38
    property string activeCategoryId: "image"
    property bool previewActive: false
    property bool isExiting: false

    property var toggleHotkey: ({ text: "Alt + F", mods: 1, vk: 0x46 })
    property var snipHotkey: ({ text: "Alt + Shift + S", mods: 5, vk: 0x53 })
    property var quickAskHotkey: ({ text: "Ctrl + Caps Lock", mods: 2, vk: 0x14 })

    property var categoriesList: []
    property var imagePromptsList: []
    property var textPromptsList: []
    property var customAskPromptsList: []
    property var customPromptsMap: ({})
    property var currentPromptsList: []
    property bool autoRun: true
    property bool startWithWindows: false

    onActiveCategoryIdChanged: root.refreshCurrentPrompts()

    // New Category State
    property bool showAddCatInput: false
    property string newCatName: ""

    // Keyboard Shortcut to Close on Escape
    Shortcut {
        sequence: "Escape"
        onActivated: root.animateClose()
    }

    function openDialog() {
        let cfg = AppManager.getSettings();
        root.currentLang = cfg.lang || "th";
        root.currentTheme = cfg.theme || "light";
        root.currentPlacement = cfg.placement || "auto";
        root.currentToolbarHeight = cfg.toolbarHeight || 38;

        root.toggleHotkey = cfg.toggleHotkey || { text: "Alt + F", mods: 1, vk: 0x46 };
        root.snipHotkey = cfg.snipHotkey || { text: "Alt + Shift + S", mods: 5, vk: 0x53 };
        root.quickAskHotkey = cfg.quickAskHotkey || { text: "Ctrl + Caps Lock", mods: 2, vk: 0x14 };

        root.imagePromptsList = JSON.parse(JSON.stringify(cfg.imagePrompts || []));
        root.textPromptsList = JSON.parse(JSON.stringify(cfg.textPrompts || []));
        if (root.textPromptsList.length === 5 && root.imagePromptsList.length >= 8) {
            root.textPromptsList = JSON.parse(JSON.stringify(root.imagePromptsList));
        }
        root.customAskPromptsList = JSON.parse(JSON.stringify(cfg.customAskPrompts || [
            {
                badge: "?",
                label: (root.currentLang === "th" ? "พิมพ์คำถามเอง (Custom Query)" : "Custom Query"),
                prompt: (root.currentLang === "th" ? "เปิดกล่องพิมพ์ข้อความ เพื่อระบุคำถามเฉพาะเจาะจงที่ต้องการถาม Gemini ทันที" : "Open inline input box to type custom question directly to Gemini.")
            }
        ]));

        let loadedCats = cfg.categories || [
            { id: "image", name: (root.currentLang === "th" ? "รูปภาพ (Screenshot)" : "Screenshot") },
            { id: "text", name: (root.currentLang === "th" ? "ข้อความ (Text)" : "Text") },
            { id: "custom", name: (root.currentLang === "th" ? "ถามเอง (Custom Ask)" : "Custom Ask") }
        ];
        root.categoriesList = JSON.parse(JSON.stringify(loadedCats));
        root.customPromptsMap = {};
        for (let i = 0; i < root.categoriesList.length; i++) {
            let cat = root.categoriesList[i];
            if (cat.prompts && Array.isArray(cat.prompts)) {
                root.customPromptsMap[cat.id] = JSON.parse(JSON.stringify(cat.prompts));
            }
        }

        root.activeCategoryId = "image";
        root.showAddCatInput = false;
        root.previewActive = false;
        root.isExiting = false;

        root.autoRun = (cfg.autoRun !== undefined) ? cfg.autoRun : true;
        root.startWithWindows = (cfg.startWithWindows !== undefined) ? cfg.startWithWindows : false;

        Theme.currentTheme = root.currentTheme;
        root.refreshCurrentPrompts();

        // Position center on screen
        root.x = (Screen.width - root.width) / 2;
        root.y = (Screen.height - root.height) / 2;

        root.show();
        root.raise();
        root.requestActivate();
        dialogOpenAnim.restart();
    }

    function animateClose() {
        if (root.isExiting) return;
        root.isExiting = true;
        dialogCloseAnim.restart();
    }

    function refreshCurrentPrompts() {
        if (root.activeCategoryId === "image") {
            root.currentPromptsList = JSON.parse(JSON.stringify(root.imagePromptsList));
        } else if (root.activeCategoryId === "text") {
            root.currentPromptsList = JSON.parse(JSON.stringify(root.textPromptsList));
        } else if (root.activeCategoryId === "custom") {
            root.currentPromptsList = JSON.parse(JSON.stringify(root.customAskPromptsList));
        } else {
            if (!root.customPromptsMap[root.activeCategoryId]) {
                root.customPromptsMap[root.activeCategoryId] = [];
            }
            root.currentPromptsList = JSON.parse(JSON.stringify(root.customPromptsMap[root.activeCategoryId]));
        }
    }

    function syncActiveCategoryPrompts() {
        let copy = JSON.parse(JSON.stringify(root.currentPromptsList));
        if (root.activeCategoryId === "image") {
            root.imagePromptsList = copy;
        } else if (root.activeCategoryId === "text") {
            root.textPromptsList = copy;
        } else if (root.activeCategoryId === "custom") {
            root.customAskPromptsList = copy;
        } else {
            root.customPromptsMap[root.activeCategoryId] = copy;
        }
    }

    function sanitizePromptsList(arr) {
        if (!Array.isArray(arr)) return [];
        let res = [];
        for (let i = 0; i < arr.length; i++) {
            let item = arr[i];
            if (item) {
                let isEn = (item.enabled !== undefined) ? (item.enabled === true || item.enabled === "true") : true;
                res.push({
                    badge: (item.badge !== undefined ? String(item.badge) : String(i + 1)).trim(),
                    label: (item.label !== undefined ? String(item.label) : "").trim(),
                    prompt: (item.prompt !== undefined ? String(item.prompt) : "").trim(),
                    enabled: isEn
                });
            }
        }
        return res;
    }

    function getCurrentPromptsList() {
        return root.currentPromptsList;
    }

    function updateCurrentPromptsList(newList) {
        let copy = JSON.parse(JSON.stringify(newList));
        if (root.activeCategoryId === "image") {
            root.imagePromptsList = copy;
        } else if (root.activeCategoryId === "text") {
            root.textPromptsList = copy;
        } else if (root.activeCategoryId === "custom") {
            root.customAskPromptsList = copy;
        } else {
            root.customPromptsMap[root.activeCategoryId] = copy;
        }
        root.currentPromptsList = copy;
    }

    function addCategory(name) {
        if (!name || name.trim().length === 0) return;
        let id = "cat_" + Date.now();
        let list = JSON.parse(JSON.stringify(root.categoriesList));
        let defaultPrompt = [
            {
                badge: "1",
                label: name.trim(),
                prompt: AppManager.isThai ? "กรุณาวิเคราะห์และให้คำตอบเกี่ยวกับประเด็นนี้อย่างชัดเจน" : "Please analyze and provide clear guidance on this topic.",
                enabled: true
            }
        ];
        list.push({ id: id, name: name.trim(), prompts: defaultPrompt });
        root.categoriesList = list;
        root.customPromptsMap[id] = JSON.parse(JSON.stringify(defaultPrompt));
        root.activeCategoryId = id;
        root.showAddCatInput = false;
        root.newCatName = "";
        root.refreshCurrentPrompts();
    }

    function deleteCategory(catId) {
        if (catId === "image" || catId === "text" || catId === "custom") return;
        let list = JSON.parse(JSON.stringify(root.categoriesList));
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === catId) {
                list.splice(i, 1);
                break;
            }
        }
        root.categoriesList = list;
        delete root.customPromptsMap[catId];
        root.activeCategoryId = "image";
        root.refreshCurrentPrompts();
    }

    function saveAndClose() {
        root.syncActiveCategoryPrompts();

        let cleanImage = root.sanitizePromptsList(root.imagePromptsList);
        let cleanText = root.sanitizePromptsList(root.textPromptsList);
        if (cleanText.length === 5 && cleanImage.length >= 8) {
            cleanText = cleanImage;
        }
        let cleanCustomAsk = root.sanitizePromptsList(root.customAskPromptsList);

        let cats = JSON.parse(JSON.stringify(root.categoriesList));
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === "image") {
                cats[i].prompts = cleanImage;
            } else if (cats[i].id === "text") {
                cats[i].prompts = cleanText;
            } else if (cats[i].id === "custom") {
                cats[i].prompts = cleanCustomAsk;
            } else if (root.customPromptsMap[cats[i].id]) {
                cats[i].prompts = root.sanitizePromptsList(root.customPromptsMap[cats[i].id]);
            }
        }

        let payload = {
            lang: root.currentLang,
            theme: root.currentTheme,
            placement: root.currentPlacement,
            toolbarHeight: root.currentToolbarHeight,
            toggleHotkey: root.toggleHotkey,
            snipHotkey: root.snipHotkey,
            quickAskHotkey: root.quickAskHotkey,
            cancelButton: { badge: "Esc", label: (root.currentLang === "th" ? "ยกเลิก" : "Cancel"), enabled: true },
            imagePrompts: cleanImage,
            textPrompts: cleanText,
            customAskPrompts: cleanCustomAsk,
            categories: cats,
            autoRun: root.autoRun,
            startWithWindows: root.startWithWindows
        };

        AppManager.saveSettings(payload);
        Theme.currentTheme = root.currentTheme;
        root.previewActive = false;
        root.animateClose();
    }

    function resetToDefaults() {
        AppManager.resetDefaults();
        openDialog();
    }

    // --- ANIMATIONS ---
    ParallelAnimation {
        id: dialogOpenAnim
        NumberAnimation {
            target: dialogCard
            property: "scale"
            from: 0.92
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
        NumberAnimation {
            target: dialogCard
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 160
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: dialogCard
            property: "yOffset"
            from: 14
            to: 0
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: dialogCloseAnim
        NumberAnimation {
            target: dialogCard
            property: "scale"
            to: 0.94
            duration: 120
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: dialogCard
            property: "opacity"
            to: 0.0
            duration: 100
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: dialogCard
            property: "yOffset"
            to: 8
            duration: 120
            easing.type: Easing.InQuad
        }
        onFinished: {
            root.visible = false;
            root.previewActive = false;
            root.isExiting = false;
        }
    }

    // Ambient Shadow Layer
    Rectangle {
        anchors.centerIn: dialogCard
        width: dialogCard.width + 12
        height: dialogCard.height + 12
        radius: 14
        color: Theme.isDark ? "#60000000" : "#1e000000"
        opacity: dialogCard.opacity
        scale: dialogCard.scale
        y: dialogCard.y + 4 + dialogCard.yOffset
    }

    // Modal Card Container (Clean, compact typography, rounded rects)
    Rectangle {
        id: dialogCard
        property real yOffset: 0
        anchors.centerIn: parent
        anchors.verticalCenterOffset: yOffset
        width: parent.width - 16
        height: parent.height - 16

        radius: 10
        color: Theme.bgDialog
        border.color: Theme.isDark ? "#353942" : "#e2e8f0"
        border.width: 1

        // 1. Header Bar (Draggable Titlebar)
        Rectangle {
            id: headerBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 44
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                property point clickPos
                onPressed: function(mouse) {
                    clickPos = Qt.point(mouse.x, mouse.y);
                }
                onPositionChanged: function(mouse) {
                    let delta = Qt.point(mouse.x - clickPos.x, mouse.y - clickPos.y);
                    root.x += delta.x;
                    root.y += delta.y;
                }
            }

            Text {
                text: AppManager.isThai ? "ตั้งค่าปุ่มลัดและคำสั่งด่วน Gemini" : "Gemini Hotkeys & Quick Prompts Settings"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Normal
                color: Theme.textPrimary
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
            }

            // Close Button ✕
            Rectangle {
                width: 26
                height: 26
                radius: 6
                color: closeMouse.containsMouse ? Theme.bgCardHover : "transparent"
                border.color: closeMouse.containsMouse ? Theme.borderLight : "transparent"
                border.width: 1
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 11
                    font.weight: Font.Normal
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.animateClose()
                }
            }
        }

        // 2. Scrollable Body
        ScrollView {
            id: mainScroll
            anchors.top: headerBar.bottom
            anchors.bottom: bottomBar.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            clip: true
            contentHeight: mainCol.implicitHeight + 16

            ScrollBar.vertical: ScrollBar {
                anchors.right: parent.right
                anchors.rightMargin: 2
                width: 5
                policy: ScrollBar.AsNeeded
            }

            Column {
                id: mainCol
                width: mainScroll.width - 10
                spacing: 10

                // Row: Language (Custom ComboBox, Real-Time Update)
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 260
                        text: AppManager.isThai ? "ภาษา / Language:" : "Language:"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    CustomComboBox {
                        customWidth: 260
                        customHeight: 32
                        model: ["ภาษาไทย (Thai)", "English"]
                        currentIndex: root.currentLang === "en" ? 1 : 0
                        onActivated: function(idx) {
                            root.currentLang = (idx === 1) ? "en" : "th";
                            AppManager.setLanguage(root.currentLang);
                        }
                    }
                }

                // Row: Theme (Custom ComboBox, Real-Time Update)
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 260
                        text: AppManager.isThai ? "ธีม (Theme):" : "Theme:"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    CustomComboBox {
                        customWidth: 260
                        customHeight: 32
                        model: [
                            AppManager.isThai ? "สว่าง (Light)" : "Light",
                            AppManager.isThai ? "มืด (Dark)" : "Dark"
                        ]
                        currentIndex: root.currentTheme === "dark" ? 1 : 0
                        onActivated: function(idx) {
                            root.currentTheme = (idx === 1) ? "dark" : "light";
                            Theme.currentTheme = root.currentTheme;
                        }
                    }
                }

                // Row: Toolbar Placement (Custom ComboBox, Real-Time Update)
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 260
                        text: AppManager.isThai ? "ตำแหน่งแถบเครื่องมือ:" : "Toolbar Placement:"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    CustomComboBox {
                        customWidth: 260
                        customHeight: 32
                        model: [
                            AppManager.isThai ? "ติดตามเมาส์/พื้นที่แคป (Auto Follow)" : "Auto Follow Cursor/Crop",
                            AppManager.isThai ? "กึ่งกลางหน้าจอ (Center Screen)" : "Center Screen"
                        ]
                        currentIndex: root.currentPlacement === "center" ? 1 : 0
                        onActivated: function(idx) {
                            root.currentPlacement = (idx === 1) ? "center" : "auto";
                            AppManager.setToolbarPlacement(root.currentPlacement);
                        }
                    }
                }

                // Row: Toolbar Slider & Real-Time Preview
                Column {
                    width: parent.width
                    spacing: 4

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - 320
                            text: AppManager.isThai ? "ขนาดแถบคำสั่งด่วน (Toolbar Size):" : "Toolbar Size:"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Normal
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Slider Control (Real-Time Live Update)
                        CustomSlider {
                            width: 180
                            from: 26
                            to: 54
                            value: root.currentToolbarHeight
                            onValueModified: function(val) {
                                root.currentToolbarHeight = val;
                                AppManager.setToolbarHeight(val);
                                if (root.previewActive) {
                                    AppManager.previewToolbar(val);
                                }
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Preview Toolbar Button
                        Rectangle {
                            width: 125
                            height: 30
                            radius: 6
                            color: testMouse.containsMouse ? Theme.bgCardHover : Theme.bgInput
                            border.color: testMouse.containsMouse ? Theme.primary : Theme.borderLight
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: AppManager.isThai ? "ทดลองแสดงแถบจริง" : "Preview Toolbar"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Normal
                                color: Theme.primary
                            }

                            MouseArea {
                                id: testMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.previewActive = true;
                                    root.syncActiveCategoryPrompts();
                                    let cleanImage = root.sanitizePromptsList(root.imagePromptsList);
                                    let cleanText = root.sanitizePromptsList(root.textPromptsList);
                                    let cleanCustomAsk = root.sanitizePromptsList(root.customAskPromptsList);
                                    let cats = JSON.parse(JSON.stringify(root.categoriesList));
                                    for (let i = 0; i < cats.length; i++) {
                                        if (cats[i].id === "image") cats[i].prompts = cleanImage;
                                        else if (cats[i].id === "text") cats[i].prompts = cleanText;
                                        else if (cats[i].id === "custom") cats[i].prompts = cleanCustomAsk;
                                        else if (root.customPromptsMap[cats[i].id]) cats[i].prompts = root.sanitizePromptsList(root.customPromptsMap[cats[i].id]);
                                    }
                                    let payload = {
                                        lang: root.currentLang,
                                        theme: root.currentTheme,
                                        placement: root.currentPlacement,
                                        toolbarHeight: root.currentToolbarHeight,
                                        toggleHotkey: root.toggleHotkey,
                                        snipHotkey: root.snipHotkey,
                                        quickAskHotkey: root.quickAskHotkey,
                                        cancelButton: { badge: "Esc", label: (root.currentLang === "th" ? "ยกเลิก" : "Cancel"), enabled: true },
                                        imagePrompts: cleanImage,
                                        textPrompts: cleanText,
                                        customAskPrompts: cleanCustomAsk,
                                        categories: cats,
                                        autoRun: root.autoRun,
                                        startWithWindows: root.startWithWindows
                                    };
                                    AppManager.saveSettings(payload);
                                    AppManager.previewToolbar(root.currentToolbarHeight, root.activeCategoryId);
                                }
                            }
                        }
                    }
                }

                // Row: Boss Key
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 260
                        text: AppManager.isThai ? "สลับเปิด/ซ่อนแอป (Boss Key):" : "Toggle Show/Hide (Boss Key):"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    CustomHotkeyBox {
                        customWidth: 260
                        customHeight: 32
                        hotkeyText: root.toggleHotkey.text || "Alt + F"
                        modifiers: root.toggleHotkey.mods || 1
                        vkCode: root.toggleHotkey.vk || 0x46
                        onHotkeyChanged: function(txt, mods, vk) {
                            root.toggleHotkey = { text: txt, mods: mods, vk: vk };
                        }
                    }
                }

                // Row: Screenshot Hotkey
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 260
                        text: AppManager.isThai ? "แคปหน้าจอถาม Gemini:" : "Capture Screen & Ask Gemini:"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    CustomHotkeyBox {
                        customWidth: 260
                        customHeight: 32
                        hotkeyText: root.snipHotkey.text || "Alt + Shift + S"
                        modifiers: root.snipHotkey.mods || 5
                        vkCode: root.snipHotkey.vk || 0x53
                        onHotkeyChanged: function(txt, mods, vk) {
                            root.snipHotkey = { text: txt, mods: mods, vk: vk };
                        }
                    }
                }

                // Row: Quick Ask Hotkey
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 260
                        text: AppManager.isThai ? "คลุมข้อความถาม Gemini:" : "Highlight Text & Ask Gemini:"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    CustomHotkeyBox {
                        customWidth: 260
                        customHeight: 32
                        hotkeyText: root.quickAskHotkey.text || "Ctrl + Caps Lock"
                        modifiers: root.quickAskHotkey.mods || 2
                        vkCode: root.quickAskHotkey.vk || 0x14
                        onHotkeyChanged: function(txt, mods, vk) {
                            root.quickAskHotkey = { text: txt, mods: mods, vk: vk };
                        }
                    }
                }

                // Divider
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.borderLight
                }

                // CATEGORIES TABS SECTION (Scrollable Horizontal Tab Bar)
                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        text: AppManager.isThai ? "หมวดหมู่คำสั่งด่วน (Command Categories):" : "Command Categories:"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: Theme.textPrimary
                    }

                    // Scrollable Category Bar Container
                    Item {
                        id: catBarContainer
                        width: parent.width
                        height: 32

                        // Left Scroll Button
                        Rectangle {
                            id: leftScrollBtn
                            width: 22
                            height: 28
                            radius: 6
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: leftScrollMouse.containsMouse ? Theme.bgCardHover : Theme.bgInput
                            border.color: Theme.borderLight
                            border.width: 1
                            visible: catFlick.contentX > 2
                            z: 10

                            Text {
                                anchors.centerIn: parent
                                text: "‹"
                                font.pixelSize: 13
                                font.weight: Font.Normal
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: leftScrollMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: catFlick.contentX = Math.max(0, catFlick.contentX - 140)
                            }
                        }

                        // Right Scroll Button
                        Rectangle {
                            id: rightScrollBtn
                            width: 22
                            height: 28
                            radius: 6
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: rightScrollMouse.containsMouse ? Theme.bgCardHover : Theme.bgInput
                            border.color: Theme.borderLight
                            border.width: 1
                            visible: catFlick.contentX < (catFlick.contentWidth - catFlick.width - 4)
                            z: 10

                            Text {
                                anchors.centerIn: parent
                                text: "›"
                                font.pixelSize: 13
                                font.weight: Font.Normal
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: rightScrollMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: catFlick.contentX = Math.min(catFlick.contentWidth - catFlick.width, catFlick.contentX + 140)
                            }
                        }

                        Flickable {
                            id: catFlick
                            anchors.fill: parent
                            anchors.leftMargin: leftScrollBtn.visible ? 26 : 0
                            anchors.rightMargin: rightScrollBtn.visible ? 26 : 0
                            contentWidth: catRowLayout.implicitWidth + 8
                            contentHeight: parent.height
                            flickableDirection: Flickable.HorizontalFlick
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            Behavior on anchors.leftMargin { NumberAnimation { duration: 100 } }
                            Behavior on anchors.rightMargin { NumberAnimation { duration: 100 } }
                            Behavior on contentX { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                            MouseArea {
                                anchors.fill: parent
                                propagateComposedEvents: true
                                onWheel: function(wheel) {
                                    let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                                    catFlick.contentX = Math.max(0, Math.min(catFlick.contentWidth - catFlick.width, catFlick.contentX - delta));
                                    wheel.accepted = true;
                                }
                            }

                            Row {
                                id: catRowLayout
                                spacing: 6
                                anchors.verticalCenter: parent.verticalCenter

                                Repeater {
                                    model: root.categoriesList

                                    delegate: Rectangle {
                                        id: catTab
                                        width: catRow.implicitWidth + 16
                                        height: 28
                                        radius: 6
                                        color: (root.activeCategoryId === modelData.id) 
                                               ? (Theme.isDark ? "#2a374a" : "#eff6ff") 
                                               : (catMouse.containsMouse ? Theme.bgCardHover : Theme.bgInput)
                                        border.color: (root.activeCategoryId === modelData.id) 
                                                      ? Theme.primary 
                                                      : (catMouse.containsMouse ? Qt.darker(Theme.borderLight, 1.4) : Theme.borderLight)
                                        border.width: 1

                                        Row {
                                            id: catRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                text: modelData.name
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Normal
                                                color: (root.activeCategoryId === modelData.id) ? Theme.primary : Theme.textPrimary
                                            }

                                            Text {
                                                text: "✕"
                                                font.pixelSize: 10
                                                font.weight: Font.Normal
                                                color: Theme.danger
                                                visible: modelData.id !== "image" && modelData.id !== "text" && modelData.id !== "custom"
                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.deleteCategory(modelData.id)
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: catMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.activeCategoryId = modelData.id
                                        }
                                    }
                                }

                                // + Add Category Button
                                Rectangle {
                                    width: addCatRow.implicitWidth + 14
                                    height: 28
                                    radius: 6
                                    color: addCatMouse.containsMouse ? Theme.bgCardHover : "transparent"
                                    border.color: Theme.borderLight
                                    border.width: 1

                                    Row {
                                        id: addCatRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: AppManager.isThai ? "+ เพิ่มหมวดหมู่" : "+ Add Category"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Normal
                                            color: Theme.primary
                                        }
                                    }

                                    MouseArea {
                                        id: addCatMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.showAddCatInput = !root.showAddCatInput
                                    }
                                }
                            }
                        }
                    }

                    // Quick Add Category Input Field
                    Rectangle {
                        id: catInputBox
                        visible: root.showAddCatInput
                        width: parent.width
                        height: 32
                        radius: 6
                        color: Theme.bgInput
                        border.color: Theme.borderFocus
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.margins: 3
                            spacing: 6

                            TextInput {
                                id: catNameInput
                                width: parent.width - 80
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Normal
                                color: Theme.textPrimary
                                selectByMouse: true
                                focus: root.showAddCatInput
                                text: root.newCatName
                                onTextChanged: root.newCatName = text
                                onAccepted: {
                                    root.addCategory(root.newCatName);
                                    text = "";
                                }
                            }

                            Rectangle {
                                width: 64
                                height: 26
                                radius: 6
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: AppManager.isThai ? "สร้าง" : "Create"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Normal
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.addCategory(root.newCatName);
                                        catNameInput.text = "";
                                    }
                                }
                            }
                        }
                    }
                }

                // Prompts Section Header & Action Buttons
                Row {
                    width: parent.width
                    topPadding: 2

                    Text {
                        width: parent.width - 140
                        text: (root.activeCategoryId === "custom")
                              ? (AppManager.isThai ? "คำสั่งด่วนสำหรับโหมดพิมพ์ถามเอง:" : "Custom Ask templates:")
                              : (AppManager.isThai ? "รายการคำสั่งสำหรับหมวดหมู่นี้:" : "Prompts for this Category:")
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: Theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // + Add Prompt Button
                    Rectangle {
                        width: addPromptText.implicitWidth + 14
                        height: 26
                        radius: 6
                        color: addMouse.containsMouse ? Theme.bgCardHover : "transparent"
                        border.color: Theme.borderLight
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: addPromptText
                            anchors.centerIn: parent
                            text: AppManager.isThai ? "+ เพิ่มคำสั่ง" : "+ Add Prompt"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Normal
                            color: Theme.primary
                        }

                        MouseArea {
                            id: addMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let list = root.getCurrentPromptsList();
                                let n = list.length + 1;
                                list.push({
                                    badge: String(n),
                                    label: AppManager.isThai ? `คำสั่งที่ ${n}` : `Prompt ${n}`,
                                    prompt: AppManager.isThai ? "กรุณา..." : "Please...",
                                    enabled: true
                                });
                                root.updateCurrentPromptsList(list);
                            }
                        }
                    }
                }

                // Dynamic Prompts Cards (Bound to reactive currentPromptsList)
                Column {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.currentPromptsList

                        delegate: CustomPromptCard {
                            width: parent.width
                            itemIndex: index
                            totalItems: root.currentPromptsList.length
                            itemEnabled: (modelData.enabled !== undefined) ? (modelData.enabled === true || modelData.enabled === "true") : true
                            badgeText: modelData.badge ? modelData.badge : String(index + 1)
                            labelText: modelData.label ? modelData.label : ""
                            promptText: modelData.prompt ? modelData.prompt : ""
                            mainScrollRef: mainScroll

                            onEnabledChanged: function(idx, isEnabled) {
                                if (idx >= 0 && idx < root.currentPromptsList.length) {
                                    root.currentPromptsList[idx].enabled = isEnabled;
                                    root.syncActiveCategoryPrompts();
                                }
                            }

                            onBadgeChanged: function(idx, newBadge) {
                                if (idx >= 0 && idx < root.currentPromptsList.length) {
                                    root.currentPromptsList[idx].badge = newBadge;
                                    root.syncActiveCategoryPrompts();
                                }
                            }

                            onLabelChanged: function(idx, newLabel) {
                                if (idx >= 0 && idx < root.currentPromptsList.length) {
                                    root.currentPromptsList[idx].label = newLabel;
                                    root.syncActiveCategoryPrompts();
                                }
                            }

                            onPromptChanged: function(idx, newPrompt) {
                                if (idx >= 0 && idx < root.currentPromptsList.length) {
                                    root.currentPromptsList[idx].prompt = newPrompt;
                                    root.syncActiveCategoryPrompts();
                                }
                            }

                            onRemove: function(idx) {
                                let list = JSON.parse(JSON.stringify(root.currentPromptsList));
                                if (idx >= 0 && idx < list.length) {
                                    list.splice(idx, 1);
                                    root.updateCurrentPromptsList(list);
                                }
                            }
                        }
                    }
                }

                // Options Checkboxes Section
                Column {
                    spacing: 6
                    topPadding: 4

                    CustomCheckBox {
                        checked: root.autoRun
                        text: AppManager.isThai ? "ส่งคำสั่งและเริ่ม Prompt ทันทีเมื่อเลือกเมนู (Auto-run)" : "Auto-run prompt immediately when action is selected"
                        onToggled: function(chk) { root.autoRun = chk; }
                    }

                    CustomCheckBox {
                        checked: root.startWithWindows
                        text: AppManager.isThai ? "เปิดโปรแกรม Google Gemini อัตโนมัติเมื่อเริ่ม Windows" : "Start Google Gemini automatically on Windows startup"
                        onToggled: function(chk) { root.startWithWindows = chk; }
                    }
                }

                Item { width: 1; height: 8 }
            }
        }

        // 3. Bottom Action Bar
        Rectangle {
            id: bottomBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 52
            radius: 10
            color: Theme.isDark ? "#181a1f" : "#ffffff"

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.borderLight
            }

            // Left: คืนค่าเริ่มต้น (Reset Defaults)
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 105
                height: 32
                radius: 6
                color: resetMouse.containsMouse ? (Theme.isDark ? "#333842" : "#e2e8f0") : (Theme.isDark ? "#252830" : "#f1f5f9")
                border.color: Theme.isDark ? "#383e4a" : "#cbd5e1"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: AppManager.isThai ? "คืนค่าเริ่มต้น" : "Reset Defaults"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Normal
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetToDefaults()
                }
            }

            // Right: Save & Cancel Buttons
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // บันทึกการตั้งค่า (Primary Blue)
                Rectangle {
                    width: 120
                    height: 32
                    radius: 6
                    color: saveMouse.containsMouse ? "#1d4ed8" : "#2563eb"

                    Text {
                        anchors.centerIn: parent
                        text: AppManager.isThai ? "บันทึกการตั้งค่า" : "Save Settings"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.saveAndClose()
                    }
                }

                // ยกเลิก (Cancel)
                Rectangle {
                    width: 75
                    height: 32
                    radius: 6
                    color: cancelMouse.containsMouse ? (Theme.isDark ? "#333842" : "#f1f5f9") : (Theme.isDark ? "#252830" : "#ffffff")
                    border.color: Theme.isDark ? "#383e4a" : "#cbd5e1"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: AppManager.isThai ? "ยกเลิก" : "Cancel"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.animateClose()
                    }
                }
            }
        }
    }
}

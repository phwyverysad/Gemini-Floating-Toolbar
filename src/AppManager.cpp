#include "AppManager.h"
#include "WebViewWindow.h"
#include <QDebug>
#include <QScreen>
#include <QGuiApplication>
#include <QClipboard>
#include <QCursor>
#include <QSettings>

#define HOTKEY_ID_TOGGLE    9001
#define HOTKEY_ID_SNIP      9002
#define HOTKEY_ID_QUICKASK  9003

AppManager* AppManager::s_instance = nullptr;

AppManager* AppManager::instance() {
    if (!s_instance) {
        s_instance = new AppManager();
    }
    return s_instance;
}

AppManager::AppManager(QObject* parent) : QObject(parent) {
    loadSettingsFromFile();
}

AppManager::~AppManager() {
    if (m_hotkeyHwnd) {
        unregisterGlobalHotkeys(m_hotkeyHwnd);
    }
}

QJsonObject AppManager::getDefaultSettingsJson() {
    QJsonObject obj;
    obj["lang"] = "th";
    obj["theme"] = "light";
    obj["placement"] = "auto";
    obj["toolbarSize"] = "normal";
    obj["toolbarHeight"] = 38;

    QJsonObject cb;
    cb["badge"] = "Esc";
    cb["label"] = "ยกเลิก";
    cb["enabled"] = true;
    obj["cancelButton"] = cb;

    obj["autoRun"] = true;
    obj["startWithWindows"] = false;

    // Hotkeys
    QJsonObject hkToggle;
    hkToggle["text"] = "Alt + F";
    hkToggle["mods"] = 1; // MOD_ALT
    hkToggle["vk"] = 0x46; // 'F'
    obj["toggleHotkey"] = hkToggle;

    QJsonObject hkSnip;
    hkSnip["text"] = "Alt + Shift + S";
    hkSnip["mods"] = 5; // MOD_ALT | MOD_SHIFT
    hkSnip["vk"] = 0x53; // 'S'
    obj["snipHotkey"] = hkSnip;

    QJsonObject hkQuick;
    hkQuick["text"] = "Ctrl + Caps Lock";
    hkQuick["mods"] = 2; // MOD_CONTROL
    hkQuick["vk"] = 0x14; // VK_CAPITAL
    obj["quickAskHotkey"] = hkQuick;

    // Default Image Prompts (Exact match to ChatGPT Image)
    QJsonArray imgPrompts;

    // Default 8 Standard Prompts (Thai / English supported)
    QJsonObject p1; p1["badge"] = "1"; p1["label"] = "คำตอบ"; p1["prompt"] = "Use simple and clear language to answer the following question. Do not translate the question. Do not wrap responses in quotes. \"\"\" ${input} \"\"\" Respond in ${lang}"; p1["enabled"] = true; imgPrompts.append(p1);
    QJsonObject p2; p2["badge"] = "2"; p2["label"] = "อธิบาย"; p2["prompt"] = "Please explain clearly and concisely in ${lang} : \"\"\"${input}\"\"\""; p2["enabled"] = true; imgPrompts.append(p2);
    QJsonObject p3; p3["badge"] = "3"; p3["label"] = "สรุป"; p3["prompt"] = "You are a highly skilled AI trained in language comprehension and summarization. I would like you to read the text delimited by triple quotes and summarize it into a concise abstract paragraph. Aim to retain the most important points, providing a coherent and readable summary that could help a person understand the main points of the discussion without needing to read the entire text. Please avoid unnecessary details or tangential points. Only give me the output and nothing else. Do not wrap responses in quotes. Respond in the ${lang} language. \"\"\" ${input} \"\"\""; p3["enabled"] = true; imgPrompts.append(p3);
    QJsonObject p4; p4["badge"] = "4"; p4["label"] = "แปลภาษา"; p4["prompt"] = "Rewrite the text in triple quotes in ${lang}. \"\"\" ${input} \"\"\" Only give me the translation and nothing else. Do not wrap responses in quotes."; p4["enabled"] = true; imgPrompts.append(p4);
    QJsonObject p5; p5["badge"] = "5"; p5["label"] = "ปรับปรุงการเขียน"; p5["prompt"] = "Rewrite the following text, which will be delimited by triple quotes, to be more concise and well-written while preserving the original meaning: \"\"\"${input}\"\"\" Provide only the rewritten text as your output, without any quotes or tags. Respond in the same language as the original text."; p5["enabled"] = true; imgPrompts.append(p5);
    QJsonObject p6; p6["badge"] = "6"; p6["label"] = "ทำให้สั้นลง"; p6["prompt"] = "Here is the original text to rewrite: \"\"\"${input}\"\"\" Please rewrite the text above to be no more than half the number of characters while keeping the core meaning the same. Output only the rewritten text, without any quotes or other formatting. Write the rewritten text in the same language as the original text."; p6["enabled"] = true; imgPrompts.append(p6);
    QJsonObject p7; p7["badge"] = "7"; p7["label"] = "ทำให้นานขึ้น"; p7["prompt"] = "Here is the original text to rewrite: \"\"\"${input}\"\"\" Please rewrite the text above to be twice as long, while keeping the core meaning the same. Do not add any completely new information, ideas or opinions. Output the rewritten, expanded text directly, without any quotes or other formatting. Write in the same language as the original text."; p7["enabled"] = true; imgPrompts.append(p7);
    QJsonObject p8; p8["badge"] = "8"; p8["label"] = "เขียนต่อ"; p8["prompt"] = "\"\"\"${input}\"\"\" Continue writing that begins with the text above and keeping the same voice and style. Stay on the same topic. Only give me the output and nothing else. Respond in the same language variety or dialect of the text above."; p8["enabled"] = true; imgPrompts.append(p8);

    obj["imagePrompts"] = imgPrompts;
    obj["textPrompts"] = imgPrompts;

    // Default Categories (No emojis)
    QJsonArray cats;
    QJsonObject c1;
    c1["id"] = "image";
    c1["name"] = "รูปภาพ (Screenshot)";
    c1["prompts"] = imgPrompts;
    cats.append(c1);

    QJsonObject c2;
    c2["id"] = "text";
    c2["name"] = "ข้อความ (Text)";
    c2["prompts"] = imgPrompts;
    cats.append(c2);

    QJsonObject c3;
    c3["id"] = "custom";
    c3["name"] = "ถามเอง (Custom Ask)";
    cats.append(c3);

    obj["categories"] = cats;

    return obj;
}

void AppManager::loadSettingsFromFile() {
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + "/GeminiDesktop";
    QDir().mkpath(configDir);
    QString configPath = configDir + "/config.json";

    QFile file(configPath);
    QJsonObject obj;

    if (file.exists() && file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        if (doc.isObject()) {
            obj = doc.object();
        }
        file.close();
    }

    if (obj.isEmpty()) {
        obj = getDefaultSettingsJson();
    }

    m_lang = obj.value("lang").toString("th");
    m_theme = obj.value("theme").toString("light");
    m_placement = obj.value("placement").toString("auto");
    m_toolbarSize = obj.value("toolbarSize").toString("normal");
    m_toolbarHeight = obj.value("toolbarHeight").toInt(38);
    m_autoRun = obj.value("autoRun").toBool(true);
    m_startWithWindows = obj.value("startWithWindows").toBool(false);

    m_toggleHotkey = obj.value("toggleHotkey").toObject();
    m_snipHotkey = obj.value("snipHotkey").toObject();
    m_quickAskHotkey = obj.value("quickAskHotkey").toObject();

    m_cancelButton = obj.value("cancelButton").toObject();
    if (m_cancelButton.isEmpty()) {
        m_cancelButton["badge"] = "Esc";
        m_cancelButton["label"] = (m_lang == "th") ? "ยกเลิก" : "Cancel";
        m_cancelButton["enabled"] = true;
    }

    m_imagePrompts = obj.value("imagePrompts").toArray().toVariantList();
    if (m_imagePrompts.isEmpty()) {
        m_imagePrompts = getDefaultSettingsJson().value("imagePrompts").toArray().toVariantList();
    }
    m_textPrompts = obj.value("textPrompts").toArray().toVariantList();
    if (m_textPrompts.isEmpty() || (m_textPrompts.size() == 5 && m_imagePrompts.size() >= 8)) {
        m_textPrompts = m_imagePrompts;
    }

    if (obj.contains("categories")) {
        m_categories = obj.value("categories").toArray().toVariantList();
        // Ensure text category is also updated if image category was updated
        for (int i = 0; i < m_categories.size(); ++i) {
            QVariantMap catMap = m_categories[i].toMap();
            if (catMap.value("id").toString() == "text") {
                QVariantList tList = catMap.value("prompts").toList();
                if (tList.size() == 5 && m_imagePrompts.size() >= 8) {
                    catMap["prompts"] = m_imagePrompts;
                    m_categories[i] = catMap;
                }
            }
        }
    } else {
        m_categories = getDefaultSettingsJson().value("categories").toArray().toVariantList();
    }

    emit settingsChanged();
}

void AppManager::saveSettingsToFile() {
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + "/GeminiDesktop";
    QDir().mkpath(configDir);
    QString configPath = configDir + "/config.json";

    QJsonObject obj = getSettings();

    QFile file(configPath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
        file.close();
    }

    applyStartupRegistry(m_startWithWindows);
    emit settingsChanged();
}

QJsonObject AppManager::getSettings() {
    QJsonObject obj;
    obj["lang"] = m_lang;
    obj["theme"] = m_theme;
    obj["placement"] = m_placement;
    obj["toolbarSize"] = m_toolbarSize;
    obj["toolbarHeight"] = m_toolbarHeight;
    obj["cancelButton"] = m_cancelButton;
    obj["autoRun"] = m_autoRun;
    obj["startWithWindows"] = m_startWithWindows;
    obj["toggleHotkey"] = m_toggleHotkey;
    obj["snipHotkey"] = m_snipHotkey;
    obj["quickAskHotkey"] = m_quickAskHotkey;
    obj["imagePrompts"] = QJsonArray::fromVariantList(m_imagePrompts);
    obj["textPrompts"] = QJsonArray::fromVariantList(m_textPrompts);
    obj["categories"] = QJsonArray::fromVariantList(m_categories);
    return obj;
}

void AppManager::saveSettings(const QJsonObject& json) {
    m_lang = json.value("lang").toString(m_lang);
    m_theme = json.value("theme").toString(m_theme);
    m_placement = json.value("placement").toString(m_placement);
    m_toolbarSize = json.value("toolbarSize").toString(m_toolbarSize);
    m_toolbarHeight = json.value("toolbarHeight").toInt(m_toolbarHeight);
    m_autoRun = json.value("autoRun").toBool(m_autoRun);
    m_startWithWindows = json.value("startWithWindows").toBool(m_startWithWindows);

    m_toggleHotkey = json.value("toggleHotkey").toObject();
    m_snipHotkey = json.value("snipHotkey").toObject();
    m_quickAskHotkey = json.value("quickAskHotkey").toObject();

    if (json.contains("cancelButton")) {
        m_cancelButton = json.value("cancelButton").toObject();
    }

    m_imagePrompts = json.value("imagePrompts").toArray().toVariantList();
    m_textPrompts = json.value("textPrompts").toArray().toVariantList();
    if (m_textPrompts.isEmpty() || (m_textPrompts.size() == 5 && m_imagePrompts.size() >= 8)) {
        m_textPrompts = m_imagePrompts;
    }

    if (json.contains("categories")) {
        m_categories = json.value("categories").toArray().toVariantList();
        for (int i = 0; i < m_categories.size(); ++i) {
            QVariantMap catMap = m_categories[i].toMap();
            if (catMap.value("id").toString() == "text") {
                QVariantList tList = catMap.value("prompts").toList();
                if (tList.size() == 5 && m_imagePrompts.size() >= 8) {
                    catMap["prompts"] = m_imagePrompts;
                    m_categories[i] = catMap;
                }
            }
        }
    }

    saveSettingsToFile();
    emit settingsChanged();

    if (m_hotkeyHwnd) {
        registerGlobalHotkeys(m_hotkeyHwnd);
    }
}

void AppManager::setLanguage(const QString& lang) {
    if (m_lang != lang) {
        m_lang = lang;
        saveSettingsToFile();
        emit settingsChanged();
    }
}

void AppManager::setToolbarPlacement(const QString& placement) {
    if (m_placement != placement) {
        m_placement = placement;
        saveSettingsToFile();
        emit settingsChanged();
    }
}

void AppManager::setToolbarHeight(int h) {
    if (h >= 24 && h <= 70) {
        m_toolbarHeight = h;
        emit settingsChanged();
    }
}

void AppManager::previewToolbar(int heightVal, const QString& targetType) {
    if (heightVal >= 24) {
        m_toolbarHeight = heightVal;
        emit settingsChanged();
    }
    QScreen* screen = QGuiApplication::primaryScreen();
    int cx = screen ? (screen->geometry().width() / 2) : 960;
    int cy = screen ? (screen->geometry().height() / 2) : 540;
    emit requestShowToolbar(targetType.isEmpty() ? "image" : targetType, cx, cy);
}

void AppManager::resetDefaults() {
    QJsonObject obj = getDefaultSettingsJson();
    saveSettings(obj);
}

void AppManager::applyStartupRegistry(bool enable) {
    QSettings bootSettings("HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run", QSettings::NativeFormat);
    QString appPath = QDir::toNativeSeparators(QGuiApplication::applicationFilePath());
    if (enable) {
        bootSettings.setValue("GoogleGeminiDesktop", "\"" + appPath + "\" --minimized");
    } else {
        bootSettings.remove("GoogleGeminiDesktop");
    }
}

void AppManager::registerGlobalHotkeys(HWND hWnd) {
    m_hotkeyHwnd = hWnd;
    unregisterGlobalHotkeys(hWnd);

    // Toggle Hotkey
    int mods1 = m_toggleHotkey.value("mods").toInt(1) | MOD_NOREPEAT;
    int vk1 = m_toggleHotkey.value("vk").toInt(0x46);
    RegisterHotKey(hWnd, HOTKEY_ID_TOGGLE, mods1, vk1);

    // Snipping Hotkey
    int mods2 = m_snipHotkey.value("mods").toInt(5) | MOD_NOREPEAT;
    int vk2 = m_snipHotkey.value("vk").toInt(0x53);
    RegisterHotKey(hWnd, HOTKEY_ID_SNIP, mods2, vk2);

    // Quick Ask Hotkey
    int mods3 = m_quickAskHotkey.value("mods").toInt(2) | MOD_NOREPEAT;
    int vk3 = m_quickAskHotkey.value("vk").toInt(0x14);
    RegisterHotKey(hWnd, HOTKEY_ID_QUICKASK, mods3, vk3);
}

void AppManager::unregisterGlobalHotkeys(HWND hWnd) {
    UnregisterHotKey(hWnd, HOTKEY_ID_TOGGLE);
    UnregisterHotKey(hWnd, HOTKEY_ID_SNIP);
    UnregisterHotKey(hWnd, HOTKEY_ID_QUICKASK);
}

void AppManager::handleGlobalHotkey(int hotkeyId) {
    switch (hotkeyId) {
    case HOTKEY_ID_TOGGLE:
        toggleMainWindow();
        break;
    case HOTKEY_ID_SNIP:
        startSnipping();
        break;
    case HOTKEY_ID_QUICKASK:
        startQuickAskFlow();
        break;
    }
}

void AppManager::startSnipping() {
    emit requestHideToolbar();
    removeToolbarKeyboardHook();

    // Ensure all pending window events/hiding are processed before grabbing screen
    QCoreApplication::processEvents();

    // 1. Capture full screen into memory BEFORE opening the overlay (Zero-Flicker architecture)
    QScreen* screen = QGuiApplication::primaryScreen();
    if (screen) {
        m_fullScreenPixmap = screen->grabWindow(0);
    }

    emit requestShowSnipping();
}

void AppManager::installToolbarKeyboardHook(const QString& targetType) {
    m_activeToolbarType = targetType;
    if (!m_toolbarKbdHook) {
        m_toolbarKbdHook = SetWindowsHookExW(WH_KEYBOARD_LL, LowLevelKeyboardProc, GetModuleHandle(nullptr), 0);
    }
}

void AppManager::removeToolbarKeyboardHook() {
    if (m_toolbarKbdHook) {
        UnhookWindowsHookEx(m_toolbarKbdHook);
        m_toolbarKbdHook = nullptr;
    }
}

LRESULT CALLBACK AppManager::LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode == HC_ACTION && (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN)) {
        KBDLLHOOKSTRUCT* pKbd = reinterpret_cast<KBDLLHOOKSTRUCT*>(lParam);
        if (pKbd && s_instance) {
            DWORD vk = pKbd->vkCode;

            if (vk == VK_ESCAPE) {
                s_instance->removeToolbarKeyboardHook();
                emit s_instance->requestHideToolbar();
                s_instance->cancelAction();
                return 1; // Handled
            }

            int actionIdx = -1;
            if (vk >= '1' && vk <= '9') {
                actionIdx = static_cast<int>(vk - '1');
            } else if (vk >= VK_NUMPAD1 && vk <= VK_NUMPAD9) {
                actionIdx = static_cast<int>(vk - VK_NUMPAD1);
            } else if (vk == VK_RETURN) {
                actionIdx = 0; // Default action 1 on Enter
            }

            if (actionIdx >= 0) {
                QString type = s_instance->m_activeToolbarType;
                s_instance->removeToolbarKeyboardHook();
                emit s_instance->requestHideToolbar();
                s_instance->triggerAction(actionIdx, type);
                return 1; // Handled
            }
        }
    }
    return CallNextHookEx(nullptr, nCode, wParam, lParam);
}

QString AppManager::autoCopySelectedText() {
    QString initialText = "";
    if (OpenClipboard(nullptr)) {
        HANDLE hData = GetClipboardData(CF_UNICODETEXT);
        if (hData) {
            wchar_t* pText = static_cast<wchar_t*>(GlobalLock(hData));
            if (pText) {
                initialText = QString::fromWCharArray(pText);
                GlobalUnlock(hData);
            }
        }
        CloseClipboard();
    }

    // Standard Copy shortcut simulation via modern SendInput (exact Google AI Studio method)
    INPUT inputs[4] = {};
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = VK_CONTROL;
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = 'C';
    inputs[2].type = INPUT_KEYBOARD;
    inputs[2].ki.wVk = 'C';
    inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;
    inputs[3].type = INPUT_KEYBOARD;
    inputs[3].ki.wVk = VK_CONTROL;
    inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(4, inputs, sizeof(INPUT));

    QString result = "";
    for (int i = 0; i < 8; i++) {
        Sleep(20);
        if (OpenClipboard(nullptr)) {
            HANDLE hData = GetClipboardData(CF_UNICODETEXT);
            if (hData) {
                wchar_t* pText = static_cast<wchar_t*>(GlobalLock(hData));
                if (pText) {
                    result = QString::fromWCharArray(pText);
                    GlobalUnlock(hData);
                }
            }
            CloseClipboard();
        }
        if (!result.isEmpty() && result != initialText) {
            return result.trimmed();
        }
    }

    if (!result.isEmpty()) return result.trimmed();
    return initialText.trimmed();
}

void AppManager::startQuickAskFlow() {
    QString text = autoCopySelectedText();
    m_activeSelectedText = text;
    m_activeBase64Image.clear();

    POINT pt;
    GetCursorPos(&pt);

    installToolbarKeyboardHook("text");
    emit requestShowToolbar("text", pt.x, pt.y);
}

void AppManager::processScreenCrop(int x, int y, int w, int h) {
    if (w <= 10 || h <= 10) return;

    QPixmap cropped;
    if (!m_fullScreenPixmap.isNull() && x >= 0 && y >= 0 && (x + w) <= m_fullScreenPixmap.width() && (y + h) <= m_fullScreenPixmap.height()) {
        cropped = m_fullScreenPixmap.copy(x, y, w, h);
    } else {
        QScreen* screen = QGuiApplication::primaryScreen();
        if (screen) {
            cropped = screen->grabWindow(0, x, y, w, h);
        }
    }

    if (cropped.isNull()) return;

    // Set Windows clipboard with cropped image
    QClipboard* clipboard = QGuiApplication::clipboard();
    if (clipboard) {
        clipboard->setPixmap(cropped);
    }

    QByteArray byteArray;
    QBuffer buffer(&byteArray);
    buffer.open(QIODevice::WriteOnly);
    cropped.save(&buffer, "PNG");

    m_activeBase64Image = QString::fromLatin1(byteArray.toBase64());
    m_activeSelectedText.clear();

    m_lastCropBottomX = x + (w / 2);
    m_lastCropBottomY = y + h;

    installToolbarKeyboardHook("image");
    emit requestShowToolbar("image", m_lastCropBottomX, m_lastCropBottomY);
}

void AppManager::exitApp() {
    removeToolbarKeyboardHook();
    if (m_hotkeyHwnd) {
        unregisterGlobalHotkeys(m_hotkeyHwnd);
    }
    if (m_webViewWindow && m_webViewWindow->getHwnd()) {
        DestroyWindow(m_webViewWindow->getHwnd());
    }
    QCoreApplication::quit();
    QCoreApplication::exit(0);
    ExitProcess(0);
}

void AppManager::triggerAction(int index, const QString& targetType) {
    removeToolbarKeyboardHook();

    QString promptTemplate = "";

    if (targetType == "image") {
        if (index >= 0 && index < m_imagePrompts.size()) {
            QVariantMap item = m_imagePrompts[index].toMap();
            promptTemplate = item.value("prompt").toString();
        }
    } else if (targetType == "text") {
        if (index >= 0 && index < m_textPrompts.size()) {
            QVariantMap item = m_textPrompts[index].toMap();
            promptTemplate = item.value("prompt").toString();
        }
    } else {
        for (const QVariant& catVar : m_categories) {
            QVariantMap catMap = catVar.toMap();
            if (catMap.value("id").toString() == targetType) {
                QVariantList catPrompts = catMap.value("prompts").toList();
                if (index >= 0 && index < catPrompts.size()) {
                    promptTemplate = catPrompts[index].toMap().value("prompt").toString();
                }
                break;
            }
        }
        if (promptTemplate.isEmpty() && index >= 0 && index < m_imagePrompts.size()) {
            promptTemplate = m_imagePrompts[index].toMap().value("prompt").toString();
        }
    }

    QString finalPrompt = promptTemplate;
    if (targetType == "text" && !m_activeSelectedText.isEmpty()) {
        finalPrompt += "\n\n" + m_activeSelectedText;
    }

    if (m_webViewWindow) {
        m_webViewWindow->injectPromptAndImage(m_activeBase64Image, finalPrompt, m_autoRun);
    }
}

void AppManager::triggerCustomPrompt(const QString& customPrompt, const QString& targetType) {
    removeToolbarKeyboardHook();

    QString finalPrompt = customPrompt.trimmed();
    if (targetType == "text" && !m_activeSelectedText.isEmpty()) {
        if (!finalPrompt.isEmpty()) {
            finalPrompt += "\n\n" + m_activeSelectedText;
        } else {
            finalPrompt = m_activeSelectedText;
        }
    }

    if (m_webViewWindow) {
        m_webViewWindow->injectPromptAndImage(m_activeBase64Image, finalPrompt, true);
    }
}

void AppManager::triggerPromptDirect(const QString& promptText, const QString& targetType) {
    removeToolbarKeyboardHook();

    QString finalPrompt = promptText.trimmed();
    if (targetType == "text" && !m_activeSelectedText.isEmpty()) {
        if (!finalPrompt.isEmpty()) {
            finalPrompt += "\n\n" + m_activeSelectedText;
        } else {
            finalPrompt = m_activeSelectedText;
        }
    }

    if (m_webViewWindow) {
        m_webViewWindow->injectPromptAndImage(m_activeBase64Image, finalPrompt, m_autoRun);
    }
}

void AppManager::cancelAction() {
    removeToolbarKeyboardHook();
    m_activeBase64Image.clear();
    m_activeSelectedText.clear();
}

void AppManager::showSettingsDialog() {
    emit requestShowSettings();
}

void AppManager::hideSettingsDialog() {
}

void AppManager::toggleMainWindow() {
    if (m_webViewWindow) {
        m_webViewWindow->toggle();
    }
}

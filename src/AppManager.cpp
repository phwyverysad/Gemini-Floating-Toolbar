#include "AppManager.h"
#include "WebViewWindow.h"
#include "SnapshotImageProvider.h"
#include "OcrEngine.h"
#include <QDebug>
#include <QScreen>
#include <QGuiApplication>
#include <QClipboard>
#include <QCursor>
#include <QSettings>
#include <QPainter>
#include <QThread>
#include <QDateTime>
#include <dwmapi.h>
#include <UIAutomationClient.h>

static IUIAutomation* g_pUIAutomation = nullptr;
static bool g_uiaInitAttempted = false;

static void EnsureUIAutomation() {
    if (!g_pUIAutomation && !g_uiaInitAttempted) {
        g_uiaInitAttempted = true;
        CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER, IID_IUIAutomation, (void**)&g_pUIAutomation);
    }
}

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

    // Default Custom Ask Prompts
    QJsonArray customAskPrompts;
    QJsonObject cap1;
    cap1["badge"] = "?";
    cap1["label"] = (m_lang == "th") ? "พิมพ์คำถามเอง" : "Custom Query";
    cap1["prompt"] = (m_lang == "th") ? "เปิดกล่องพิมพ์ข้อความ เพื่อระบุคำถามเฉพาะเจาะจงที่ต้องการถาม Gemini ทันที" : "Open inline input box to type custom question directly to Gemini.";
    cap1["enabled"] = true;
    customAskPrompts.append(cap1);

    obj["imagePrompts"] = imgPrompts;
    obj["textPrompts"] = imgPrompts;
    obj["customAskPrompts"] = customAskPrompts;

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
    c3["prompts"] = customAskPrompts;
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
    if (m_textPrompts.isEmpty()) {
        m_textPrompts = m_imagePrompts;
    }

    if (obj.contains("categories")) {
        m_categories = obj.value("categories").toArray().toVariantList();
    } else {
        m_categories = getDefaultSettingsJson().value("categories").toArray().toVariantList();
    }

    if (obj.contains("customAskPrompts")) {
        m_customAskPrompts = obj.value("customAskPrompts").toArray().toVariantList();
    } else {
        for (const QVariant& cVar : m_categories) {
            QVariantMap cMap = cVar.toMap();
            if (cMap.value("id").toString() == "custom") {
                m_customAskPrompts = cMap.value("prompts").toList();
                break;
            }
        }
        if (m_customAskPrompts.isEmpty()) {
            m_customAskPrompts = getDefaultSettingsJson().value("customAskPrompts").toArray().toVariantList();
        }
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
    obj["customAskPrompts"] = QJsonArray::fromVariantList(m_customAskPrompts);
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
    if (m_textPrompts.isEmpty()) {
        m_textPrompts = m_imagePrompts;
    }

    if (json.contains("customAskPrompts")) {
        m_customAskPrompts = json.value("customAskPrompts").toArray().toVariantList();
    }

    if (json.contains("categories")) {
        m_categories = json.value("categories").toArray().toVariantList();
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
        QString oldLabel = m_cancelButton.value("label").toString();
        if (oldLabel == "ยกเลิก" || oldLabel == "Cancel" || oldLabel.isEmpty()) {
            m_cancelButton["label"] = (m_lang == "th") ? "ยกเลิก" : "Cancel";
        }
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
    if (!RegisterHotKey(hWnd, HOTKEY_ID_TOGGLE, mods1, vk1)) {
        qWarning() << "Failed to register toggle hotkey, error:" << GetLastError();
    }

    // Snipping Hotkey
    int mods2 = m_snipHotkey.value("mods").toInt(5) | MOD_NOREPEAT;
    int vk2 = m_snipHotkey.value("vk").toInt(0x53);
    if (!RegisterHotKey(hWnd, HOTKEY_ID_SNIP, mods2, vk2)) {
        qWarning() << "Failed to register snipping hotkey, error:" << GetLastError();
    }

    // Quick Ask Hotkey
    int mods3 = m_quickAskHotkey.value("mods").toInt(2) | MOD_NOREPEAT;
    int vk3 = m_quickAskHotkey.value("vk").toInt(0x14);
    if (!RegisterHotKey(hWnd, HOTKEY_ID_QUICKASK, mods3, vk3)) {
        qWarning() << "Failed to register quick ask hotkey, error:" << GetLastError();
    }
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

QRect AppManager::getVirtualDesktopGeometry() {
    QList<QScreen*> screens = QGuiApplication::screens();
    if (!screens.isEmpty()) {
        QRect virtualGeo;
        for (QScreen* s : screens) {
            virtualGeo = virtualGeo.united(s->geometry());
        }
        if (!virtualGeo.isEmpty() && virtualGeo.width() > 100 && virtualGeo.height() > 100) {
            return virtualGeo;
        }
    }
    int vx = GetSystemMetrics(SM_XVIRTUALSCREEN);
    int vy = GetSystemMetrics(SM_YVIRTUALSCREEN);
    int vw = GetSystemMetrics(SM_CXVIRTUALSCREEN);
    int vh = GetSystemMetrics(SM_CYVIRTUALSCREEN);

    if (vw <= 0 || vh <= 0) {
        vx = 0; vy = 0;
        vw = GetSystemMetrics(SM_CXSCREEN);
        vh = GetSystemMetrics(SM_CYSCREEN);
    }
    return QRect(vx, vy, vw, vh);
}

QPixmap AppManager::captureNativeDesktop() {
    QRect vGeo = getVirtualDesktopGeometry();
    int vx = vGeo.x();
    int vy = vGeo.y();
    int vw = vGeo.width();
    int vh = vGeo.height();

    HDC hScreenDC = GetDC(nullptr);
    if (!hScreenDC) return QPixmap();

    HDC hMemoryDC = CreateCompatibleDC(hScreenDC);
    if (!hMemoryDC) {
        ReleaseDC(nullptr, hScreenDC);
        return QPixmap();
    }

    HBITMAP hBitmap = CreateCompatibleBitmap(hScreenDC, vw, vh);
    if (!hBitmap) {
        DeleteDC(hMemoryDC);
        ReleaseDC(nullptr, hScreenDC);
        return QPixmap();
    }

    HBITMAP hOldBitmap = static_cast<HBITMAP>(SelectObject(hMemoryDC, hBitmap));
    BitBlt(hMemoryDC, 0, 0, vw, vh, hScreenDC, vx, vy, SRCCOPY | CAPTUREBLT);
    SelectObject(hMemoryDC, hOldBitmap);

    BITMAPINFO bi = {};
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = vw;
    bi.bmiHeader.biHeight = -vh; // Top-down DIB
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    QImage image(vw, vh, QImage::Format_RGB32);
    GetDIBits(hScreenDC, hBitmap, 0, vh, image.bits(), &bi, DIB_RGB_COLORS);

    DeleteObject(hBitmap);
    DeleteDC(hMemoryDC);
    ReleaseDC(nullptr, hScreenDC);

    return QPixmap::fromImage(image);
}

void AppManager::startSnipping() {
    // 1. If WebView window is open, hide it temporarily so it is not in the screenshot
    if (m_webViewWindow && m_webViewWindow->getHwnd()) {
        HWND hWeb = m_webViewWindow->getHwnd();
        if (IsWindowVisible(hWeb) && !IsIconic(hWeb)) {
            m_webViewWasVisible = true;
            ShowWindow(hWeb, SW_HIDE);
        } else {
            m_webViewWasVisible = false;
        }
    }

    // 2. Instantly hide any visible toolbar without fade animation
    emit requestHideImmediateToolbar();
    removeToolbarKeyboardHook();

    if (m_webViewWasVisible) {
        QCoreApplication::processEvents();
        QThread::msleep(25);
        QCoreApplication::processEvents();
    } else {
        QCoreApplication::processEvents();
    }

    // 3. Robust Multi-Monitor Screenshot Capture with high-DPI precision
    QList<QScreen*> screens = QGuiApplication::screens();
    if (screens.size() == 1) {
        m_fullScreenPixmap = screens.first()->grabWindow(0);
    } else if (screens.size() > 1) {
        QRect virtualGeo = getVirtualDesktopGeometry();
        QImage compositeImage(virtualGeo.size(), QImage::Format_RGB32);
        compositeImage.fill(Qt::black);
        QPainter painter(&compositeImage);
        for (QScreen* s : screens) {
            QPixmap screenPix = s->grabWindow(0);
            int targetX = s->geometry().x() - virtualGeo.x();
            int targetY = s->geometry().y() - virtualGeo.y();
            painter.drawPixmap(targetX, targetY, s->geometry().width(), s->geometry().height(), screenPix);
        }
        painter.end();
        m_fullScreenPixmap = QPixmap::fromImage(compositeImage);
    } else {
        m_fullScreenPixmap = captureNativeDesktop();
    }

    if (m_fullScreenPixmap.isNull() || m_fullScreenPixmap.width() < 50 || m_fullScreenPixmap.height() < 50) {
        m_fullScreenPixmap = captureNativeDesktop();
    }

    m_virtualOrigin = getVirtualDesktopGeometry().topLeft();
    m_snapshotTimestamp = QDateTime::currentMSecsSinceEpoch();
    SnapshotImageProvider::instance()->setSnapshot(m_fullScreenPixmap);

    emit requestShowSnipping();
}

// --- ULTRA-SMART MULTI-SCALE DETECTION ENGINE (Micro-Icons, Text Lines, UI Controls, Cards) ---

static inline int colorDiff(QRgb c1, QRgb c2) {
    return qAbs(qRed(c1) - qRed(c2)) + qAbs(qGreen(c1) - qGreen(c2)) + qAbs(qBlue(c1) - qBlue(c2));
}

// 1. Ultra-Precise Micro-Icon & Glyph Detector (Detects icons from 6x6 to 52x52: status dots, favicons, buttons, arrows, checkboxes)
static QRect detectMicroIconOrGlyph(const QImage& img, int px, int py) {
    int imgW = img.width();
    int imgH = img.height();
    if (px < 0 || px >= imgW || py < 0 || py >= imgH) return QRect();

    // Check a local 48x48 window
    int winRadius = 24;
    int x0 = qMax(0, px - winRadius);
    int y0 = qMax(0, py - winRadius);
    int x1 = qMin(imgW - 1, px + winRadius);
    int y1 = qMin(imgH - 1, py + winRadius);

    // Sample background color from the 4 corner pixels of the window
    QRgb cTL = img.pixel(x0, y0);
    QRgb cTR = img.pixel(x1, y0);
    QRgb cBL = img.pixel(x0, y1);
    QRgb cBR = img.pixel(x1, y1);

    // If corners are reasonably uniform, that is our background
    QRgb bg = cTL;
    if (colorDiff(cTR, cTL) < 30) bg = cTR;
    else if (colorDiff(cBL, cTL) < 30) bg = cBL;
    else if (colorDiff(cBR, cTL) < 30) bg = cBR;

    // Search for the closest high-contrast foreground pixel within 6px of (px, py)
    int startX = -1, startY = -1;
    int bestDist = 999;
    for (int dy = -6; dy <= 6; dy++) {
        for (int dx = -6; dx <= 6; dx++) {
            int cx = px + dx;
            int cy = py + dy;
            if (cx >= x0 && cx <= x1 && cy >= y0 && cy <= y1) {
                if (colorDiff(img.pixel(cx, cy), bg) > 28) {
                    int dist = dx * dx + dy * dy;
                    if (dist < bestDist) {
                        bestDist = dist;
                        startX = cx;
                        startY = cy;
                    }
                }
            }
        }
    }

    if (startX < 0) return QRect();

    // BFS Flood-fill to find the exact bounding box of the connected glyph/icon island
    int minX = startX, maxX = startX, minY = startY, maxY = startY;
    QVector<QPoint> queue;
    queue.reserve(512);
    queue.append(QPoint(startX, startY));

    // Visited bitmap within the local 48x48 window
    const int W = x1 - x0 + 1;
    const int H = y1 - y0 + 1;
    QVector<bool> visited(W * H, false);
    visited[(startY - y0) * W + (startX - x0)] = true;

    int head = 0;
    while (head < queue.size() && queue.size() < 400) {
        QPoint p = queue[head++];
        int cx = p.x();
        int cy = p.y();

        if (cx < minX) minX = cx;
        if (cx > maxX) maxX = cx;
        if (cy < minY) minY = cy;
        if (cy > maxY) maxY = cy;

        // 4-neighborhood expansion
        const int dxs[4] = { 1, -1, 0, 0 };
        const int dys[4] = { 0, 0, 1, -1 };
        for (int i = 0; i < 4; i++) {
            int nx = cx + dxs[i];
            int ny = cy + dys[i];
            if (nx >= x0 && nx <= x1 && ny >= y0 && ny <= y1) {
                int vIdx = (ny - y0) * W + (nx - x0);
                if (!visited[vIdx]) {
                    visited[vIdx] = true;
                    if (colorDiff(img.pixel(nx, ny), bg) > 22) {
                        queue.append(QPoint(nx, ny));
                    }
                }
            }
        }
    }

    int iconW = maxX - minX + 1;
    int iconH = maxY - minY + 1;

    // Check if valid micro-icon / glyph / button dot
    if (iconW >= 5 && iconW <= 54 && iconH >= 5 && iconH <= 54) {
        // Add subtle 2px padding for clean visual capture
        int pad = 2;
        int rx = qMax(0, minX - pad);
        int ry = qMax(0, minY - pad);
        int rw = qMin(imgW - rx, iconW + pad * 2);
        int rh = qMin(imgH - ry, iconH + pad * 2);
        return QRect(rx, ry, rw, rh);
    }

    return QRect();
}

// 2. High-Precision Text-Line & Word Detector (Detects single lines, sentences, phrases, and code lines)
static QRect detectTextLineOrPhrase(const QImage& img, int px, int py) {
    int imgW = img.width();
    int imgH = img.height();
    if (px < 0 || px >= imgW || py < 0 || py >= imgH) return QRect();

    // Scan vertical extent of the text line around (px, py)
    int lineTop = py;
    while (lineTop > qMax(0, py - 35)) {
        bool hasContrast = false;
        for (int dx = -28; dx <= 28; dx += 6) {
            int x = qBound(0, px + dx, imgW - 1);
            QRgb c1 = img.pixel(x, lineTop);
            QRgb c2 = img.pixel(x, qMax(0, lineTop - 1));
            if (colorDiff(c1, c2) > 30) {
                hasContrast = true;
                break;
            }
        }
        if (!hasContrast) break;
        lineTop--;
    }

    int lineBottom = py;
    while (lineBottom < qMin(imgH - 1, py + 35)) {
        bool hasContrast = false;
        for (int dx = -28; dx <= 28; dx += 6) {
            int x = qBound(0, px + dx, imgW - 1);
            QRgb c1 = img.pixel(x, lineBottom);
            QRgb c2 = img.pixel(x, qMin(imgH - 1, lineBottom + 1));
            if (colorDiff(c1, c2) > 30) {
                hasContrast = true;
                break;
            }
        }
        if (!hasContrast) break;
        lineBottom++;
    }

    int textH = lineBottom - lineTop;
    if (textH >= 7 && textH <= 42) {
        // Expand horizontally along this line of text
        int lineLeft = px;
        int emptyStreak = 0;
        while (lineLeft > qMax(0, px - 650)) {
            bool hasPixel = false;
            for (int y = lineTop; y <= lineBottom; y += 3) {
                QRgb c = img.pixel(lineLeft, y);
                QRgb cBg = img.pixel(lineLeft, qMax(0, lineTop - 2));
                if (colorDiff(c, cBg) > 28) {
                    hasPixel = true;
                    break;
                }
            }
            if (hasPixel) {
                emptyStreak = 0;
            } else {
                emptyStreak++;
                if (emptyStreak > 18) {
                    lineLeft += emptyStreak;
                    break;
                }
            }
            lineLeft--;
        }

        int lineRight = px;
        emptyStreak = 0;
        while (lineRight < qMin(imgW - 1, px + 650)) {
            bool hasPixel = false;
            for (int y = lineTop; y <= lineBottom; y += 3) {
                QRgb c = img.pixel(lineRight, y);
                QRgb cBg = img.pixel(lineRight, qMax(0, lineTop - 2));
                if (colorDiff(c, cBg) > 28) {
                    hasPixel = true;
                    break;
                }
            }
            if (hasPixel) {
                emptyStreak = 0;
            } else {
                emptyStreak++;
                if (emptyStreak > 18) {
                    lineRight -= emptyStreak;
                    break;
                }
            }
            lineRight++;
        }

        int textW = lineRight - lineLeft;
        if (textW >= 14 && textH >= 7) {
            int pad = 2;
            int rx = qMax(0, lineLeft - pad);
            int ry = qMax(0, lineTop - pad);
            int rw = qMin(imgW - rx, textW + pad * 2);
            int rh = qMin(imgH - ry, textH + pad * 2);
            return QRect(rx, ry, rw, rh);
        }
    }

    return QRect();
}

// 3. Card, Button, Input, Table Cell & Container Detector
static QRect detectCardOrContainer(const QImage& img, int px, int py) {
    int imgW = img.width();
    int imgH = img.height();
    if (px < 0 || px >= imgW || py < 0 || py >= imgH) return QRect();

    QRgb seedColor = img.pixel(px, py);

    auto isEdge = [&](int x, int y) {
        if (x < 0 || x >= imgW || y < 0 || y >= imgH) return true;
        return colorDiff(img.pixel(x, y), seedColor) > 50;
    };

    int maxSpan = 500;
    int left = px, right = px, top = py, bottom = py;

    while (left > qMax(0, px - maxSpan) && !isEdge(left, py)) left--;
    while (right < qMin(imgW - 1, px + maxSpan) && !isEdge(right, py)) right++;
    while (top > qMax(0, py - maxSpan) && !isEdge(px, top)) top--;
    while (bottom < qMin(imgH - 1, py + maxSpan) && !isEdge(px, bottom)) bottom++;

    int detW = right - left;
    int detH = bottom - top;

    if (detW >= 24 && detH >= 18) {
        return QRect(left, top, detW, detH);
    }

    return QRect();
}

QRect AppManager::detectElementBounds(int localX, int localY) {
    if (m_fullScreenPixmap.isNull()) {
        return QRect(qMax(0, localX - 60), qMax(0, localY - 40), 120, 80);
    }

    int globalX = m_virtualOrigin.x() + localX;
    int globalY = m_virtualOrigin.y() + localY;
    POINT pt = { globalX, globalY };

    QImage img = m_fullScreenPixmap.toImage();
    int imgW = img.width();
    int imgH = img.height();
    int px = qBound(0, localX, imgW - 1);
    int py = qBound(0, localY, imgH - 1);

    // --- PRIORITY 1: Micro-Icon / Status Dot / Badge / Small Glyph (Size 6x6 to 52x52) ---
    QRect microIcon = detectMicroIconOrGlyph(img, px, py);
    if (microIcon.isValid() && microIcon.width() >= 5 && microIcon.height() >= 5 && microIcon.width() <= 54 && microIcon.height() <= 54) {
        return microIcon;
    }

    // --- PRIORITY 2: Text-Line / Word / Sentence (Height 7px to 42px) ---
    QRect textLine = detectTextLineOrPhrase(img, px, py);
    if (textLine.isValid() && textLine.width() >= 14 && textLine.height() >= 7) {
        return textLine;
    }

    // --- PRIORITY 3: Windows UI Automation (UIA) for DOM Controls, Buttons, Inputs, Cards ---
    QRect uiaCandidate;
    EnsureUIAutomation();
    if (g_pUIAutomation) {
        IUIAutomationElement* pElement = nullptr;
        HRESULT hr = g_pUIAutomation->ElementFromPoint(pt, &pElement);
        if (SUCCEEDED(hr) && pElement) {
            RECT uiaRect = {};
            hr = pElement->get_CurrentBoundingRectangle(&uiaRect);
            pElement->Release();

            if (SUCCEEDED(hr)) {
                int w = uiaRect.right - uiaRect.left;
                int h = uiaRect.bottom - uiaRect.top;
                if (w > 10 && h > 8 && (w < m_fullScreenPixmap.width() * 0.96 || h < m_fullScreenPixmap.height() * 0.96)) {
                    int normX = uiaRect.left - m_virtualOrigin.x();
                    int normY = uiaRect.top - m_virtualOrigin.y();
                    uiaCandidate = QRect(normX, normY, w, h);

                    // If UIA found a precise control (Button, Image, CheckBox <= 240x120), return immediately!
                    if (w <= 240 && h <= 120) {
                        return uiaCandidate;
                    }
                }
            }
        }
    }

    // --- PRIORITY 4: Visual Card / Button / Container ---
    QRect visualCard = detectCardOrContainer(img, px, py);
    if (visualCard.isValid() && visualCard.width() >= 24 && visualCard.height() >= 18 && (visualCard.width() <= 600 || visualCard.height() <= 400)) {
        return visualCard;
    }

    // --- PRIORITY 5: Return UIA Container if available ---
    if (uiaCandidate.isValid()) {
        return uiaCandidate;
    }

    // --- PRIORITY 6: Win32 Window Hierarchy Fallback ---
    HWND hwnd = WindowFromPoint(pt);
    if (hwnd) {
        POINT clientPt = pt;
        ScreenToClient(hwnd, &clientPt);
        HWND childHwnd = RealChildWindowFromPoint(hwnd, clientPt);
        if (childHwnd && childHwnd != hwnd && IsWindowVisible(childHwnd)) {
            hwnd = childHwnd;
        }

        RECT rc = {};
        HRESULT hr = DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, &rc, sizeof(rc));
        if (FAILED(hr) || rc.right <= rc.left || rc.bottom <= rc.top) {
            GetWindowRect(hwnd, &rc);
        }

        int winW = rc.right - rc.left;
        int winH = rc.bottom - rc.top;

        if (winW > 15 && winH > 15 && (winW < m_fullScreenPixmap.width() * 0.96 || winH < m_fullScreenPixmap.height() * 0.96)) {
            int normX = rc.left - m_virtualOrigin.x();
            int normY = rc.top - m_virtualOrigin.y();
            return QRect(normX, normY, winW, winH);
        }
    }

    if (visualCard.isValid()) {
        return visualCard;
    }

    return QRect(qMax(0, localX - 100), qMax(0, localY - 60), 200, 120);
}

QJsonObject AppManager::detectWindowAt(int screenX, int screenY) {
    QJsonObject result;
    result["found"] = false;

    if (m_fullScreenPixmap.isNull()) return result;

    int globalX = m_virtualOrigin.x() + screenX;
    int globalY = m_virtualOrigin.y() + screenY;
    POINT pt = { globalX, globalY };

    struct WindowSearchContext {
        POINT pt;
        HWND foundHwnd = nullptr;
        RECT foundRect = {};
        QString title;
        HWND webHwnd = nullptr;
    } ctx;

    ctx.pt = pt;
    if (m_webViewWindow) ctx.webHwnd = m_webViewWindow->getHwnd();

    // EnumWindows enumerates top-level windows in top-to-bottom Z-order
    EnumWindows([](HWND hwnd, LPARAM lParam) -> BOOL {
        WindowSearchContext* pCtx = reinterpret_cast<WindowSearchContext*>(lParam);
        if (!IsWindowVisible(hwnd) || IsIconic(hwnd)) return TRUE;

        // Skip our own web view
        if (hwnd == pCtx->webHwnd) return TRUE;

        LONG exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
        if (exStyle & WS_EX_TOOLWINDOW) return TRUE;

        // Check if window is a layered/transparent utility overlay
        char className[256] = { 0 };
        GetClassNameA(hwnd, className, 256);
        if (strstr(className, "Qt") || strstr(className, "Tool") || strstr(className, "Overlay")) {
            if (exStyle & WS_EX_LAYERED) {
                wchar_t testTitle[64] = { 0 };
                GetWindowTextW(hwnd, testTitle, 64);
                if (wcslen(testTitle) == 0) return TRUE;
            }
        }

        // Get exact DWM frame bounds (including shadowless accurate geometry)
        RECT rc = {};
        HRESULT hr = DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, &rc, sizeof(rc));
        if (FAILED(hr) || rc.right <= rc.left || rc.bottom <= rc.top) {
            GetWindowRect(hwnd, &rc);
        }

        if (PtInRect(&rc, pCtx->pt)) {
            int w = rc.right - rc.left;
            int h = rc.bottom - rc.top;

            if (w >= 100 && h >= 80) {
                wchar_t titleBuf[512] = { 0 };
                GetWindowTextW(hwnd, titleBuf, 512);
                QString titleStr = QString::fromWCharArray(titleBuf).trimmed();

                pCtx->foundHwnd = hwnd;
                pCtx->foundRect = rc;
                pCtx->title = titleStr;
                return FALSE; // Found topmost window under cursor!
            }
        }
        return TRUE;
    }, reinterpret_cast<LPARAM>(&ctx));

    // Fallback to WindowFromPoint if EnumWindows didn't match
    if (!ctx.foundHwnd) {
        HWND hwnd = WindowFromPoint(pt);
        if (hwnd) {
            HWND root = GetAncestor(hwnd, GA_ROOT);
            if (root && IsWindowVisible(root) && !IsIconic(root) && root != ctx.webHwnd) {
                RECT rc = {};
                HRESULT hr = DwmGetWindowAttribute(root, DWMWA_EXTENDED_FRAME_BOUNDS, &rc, sizeof(rc));
                if (FAILED(hr)) GetWindowRect(root, &rc);

                int w = rc.right - rc.left;
                int h = rc.bottom - rc.top;
                if (w >= 100 && h >= 80) {
                    wchar_t titleBuf[512] = { 0 };
                    GetWindowTextW(root, titleBuf, 512);
                    ctx.foundHwnd = root;
                    ctx.foundRect = rc;
                    ctx.title = QString::fromWCharArray(titleBuf).trimmed();
                }
            }
        }
    }

    if (ctx.foundHwnd) {
        int localX = ctx.foundRect.left - m_virtualOrigin.x();
        int localY = ctx.foundRect.top - m_virtualOrigin.y();
        int localW = ctx.foundRect.right - ctx.foundRect.left;
        int localH = ctx.foundRect.bottom - ctx.foundRect.top;

        int virtW = m_fullScreenPixmap.width();
        int virtH = m_fullScreenPixmap.height();
        if (localX < 0) { localW += localX; localX = 0; }
        if (localY < 0) { localH += localY; localY = 0; }
        if (localX + localW > virtW) localW = virtW - localX;
        if (localY + localH > virtH) localH = virtH - localY;

        if (localW > 50 && localH > 50) {
            result["found"] = true;
            result["x"] = localX;
            result["y"] = localY;
            result["width"] = localW;
            result["height"] = localH;
            result["title"] = ctx.title.isEmpty() ? (isThai() ? "หน้าต่างแอปพลิเคชัน" : "Application Window") : ctx.title;
        }
    }

    return result;
}

QRect AppManager::autoFitElementBounds(int rx, int ry, int rw, int rh) {
    if (m_fullScreenPixmap.isNull() || rw <= 5 || rh <= 5) {
        return QRect(rx, ry, rw, rh);
    }

    QImage img = m_fullScreenPixmap.toImage();
    int imgW = img.width();
    int imgH = img.height();

    int clampX = qBound(0, rx, imgW - 1);
    int clampY = qBound(0, ry, imgH - 1);
    int clampW = qMin(rw, imgW - clampX);
    int clampH = qMin(rh, imgH - clampY);

    if (clampW <= 5 || clampH <= 5) {
        return QRect(rx, ry, rw, rh);
    }

    // --- STRATEGY 1: Text-Paragraph & Multi-Line Text Auto-Fit ---
    int textMinX = 99999, textMaxX = -1;
    int textMinY = 99999, textMaxY = -1;
    int detectedLineCount = 0;

    int stepY = qMax(2, clampH / 40);
    for (int y = clampY; y < clampY + clampH; y += stepY) {
        int sampleX = clampX + clampW / 2;
        QRect lineRect = detectTextLineOrPhrase(img, sampleX, y);
        if (lineRect.isValid() && lineRect.height() >= 6 && lineRect.height() <= 45) {
            if (lineRect.bottom() >= clampY && lineRect.top() <= clampY + clampH) {
                detectedLineCount++;
                if (lineRect.left() < textMinX) textMinX = lineRect.left();
                if (lineRect.right() > textMaxX) textMaxX = lineRect.right();
                if (lineRect.top() < textMinY) textMinY = lineRect.top();
                if (lineRect.bottom() > textMaxY) textMaxY = lineRect.bottom();
                y = lineRect.bottom();
            }
        }
    }

    if (detectedLineCount >= 1 && textMaxX > textMinX && textMaxY > textMinY) {
        int fitW = textMaxX - textMinX + 1;
        int fitH = textMaxY - textMinY + 1;
        if (fitW >= 14 && fitH >= 7) {
            int pad = 4;
            int finalX = qMax(0, textMinX - pad);
            int finalY = qMax(0, textMinY - pad);
            int finalW = qMin(imgW - finalX, fitW + pad * 2);
            int finalH = qMin(imgH - finalY, fitH + pad * 2);
            return QRect(finalX, finalY, finalW, finalH);
        }
    }

    // --- STRATEGY 2: UI Automation Enclosing Container / Control ---
    EnsureUIAutomation();
    if (g_pUIAutomation) {
        int centerX = m_virtualOrigin.x() + clampX + clampW / 2;
        int centerY = m_virtualOrigin.y() + clampY + clampH / 2;
        POINT pt = { centerX, centerY };

        IUIAutomationElement* pElement = nullptr;
        if (SUCCEEDED(g_pUIAutomation->ElementFromPoint(pt, &pElement)) && pElement) {
            RECT uiaRect = {};
            if (SUCCEEDED(pElement->get_CurrentBoundingRectangle(&uiaRect))) {
                int uW = uiaRect.right - uiaRect.left;
                int uH = uiaRect.bottom - uiaRect.top;
                int normX = uiaRect.left - m_virtualOrigin.x();
                int normY = uiaRect.top - m_virtualOrigin.y();

                if (uW > 15 && uH > 15 && (uW < m_fullScreenPixmap.width() * 0.96 || uH < m_fullScreenPixmap.height() * 0.96)) {
                    QRect uRect(normX, normY, uW, uH);
                    QRect roughRect(clampX, clampY, clampW, clampH);
                    QRect intersected = uRect.intersected(roughRect);
                    double overlap = (double)(intersected.width() * intersected.height()) / (double)(clampW * clampH);
                    if (overlap >= 0.55 && uW <= clampW * 2.2 && uH <= clampH * 2.2) {
                        pElement->Release();
                        return uRect;
                    }
                }
            }
            pElement->Release();
        }
    }

    // --- STRATEGY 3: Visual Card / Border Edge Snapping ---
    int expandLimit = 80;
    int bestL = clampX, bestR = clampX + clampW, bestT = clampY, bestB = clampY + clampH;

    // Left boundary
    for (int l = clampX; l >= qMax(0, clampX - expandLimit); l--) {
        int edgePixels = 0;
        for (int y = clampY; y <= clampY + clampH; y += 4) {
            if (colorDiff(img.pixel(l, y), img.pixel(qMax(0, l - 1), y)) > 40) {
                edgePixels++;
            }
        }
        if (edgePixels > (clampH / 8)) {
            bestL = l;
            break;
        }
    }

    // Right boundary
    for (int r = clampX + clampW; r <= qMin(imgW - 1, clampX + clampW + expandLimit); r++) {
        int edgePixels = 0;
        for (int y = clampY; y <= clampY + clampH; y += 4) {
            if (colorDiff(img.pixel(r, y), img.pixel(qMin(imgW - 1, r + 1), y)) > 40) {
                edgePixels++;
            }
        }
        if (edgePixels > (clampH / 8)) {
            bestR = r;
            break;
        }
    }

    // Top boundary
    for (int t = clampY; t >= qMax(0, clampY - expandLimit); t--) {
        int edgePixels = 0;
        for (int x = clampX; x <= clampX + clampW; x += 4) {
            if (colorDiff(img.pixel(x, t), img.pixel(x, qMax(0, t - 1))) > 40) {
                edgePixels++;
            }
        }
        if (edgePixels > (clampW / 8)) {
            bestT = t;
            break;
        }
    }

    // Bottom boundary
    for (int b = clampY + clampH; b <= qMin(imgH - 1, clampY + clampH + expandLimit); b++) {
        int edgePixels = 0;
        for (int x = clampX; x <= clampX + clampW; x += 4) {
            if (colorDiff(img.pixel(x, b), img.pixel(x, qMin(imgH - 1, b + 1))) > 40) {
                edgePixels++;
            }
        }
        if (edgePixels > (clampW / 8)) {
            bestB = b;
            break;
        }
    }

    int autoW = bestR - bestL;
    int autoH = bestB - bestT;

    if (autoW >= clampW && autoH >= clampH && autoW <= clampW * 1.5 && autoH <= clampH * 1.5) {
        return QRect(bestL, bestT, autoW, autoH);
    }

    return QRect(clampX, clampY, clampW, clampH);
}

QRect AppManager::snapSelectionToContent(int x, int y, int w, int h, int snapThreshold) {
    if (m_fullScreenPixmap.isNull() || w < 8 || h < 8) return QRect(x, y, w, h);

    QImage img = m_fullScreenPixmap.toImage();
    int imgW = img.width();
    int imgH = img.height();

    int left = qBound(0, x, imgW - 1);
    int top = qBound(0, y, imgH - 1);
    int right = qBound(0, x + w, imgW - 1);
    int bottom = qBound(0, y + h, imgH - 1);

    // 1. Magnetic Left Edge Snapping
    int bestL = left, bestLScore = 0;
    for (int dx = -snapThreshold; dx <= snapThreshold; dx++) {
        int cx = left + dx;
        if (cx > 0 && cx < imgW - 1) {
            int edgeCount = 0;
            for (int cy = top; cy <= bottom; cy += 4) {
                if (colorDiff(img.pixel(cx, cy), img.pixel(cx - 1, cy)) > 35) edgeCount++;
            }
            if (edgeCount > bestLScore && edgeCount >= (bottom - top) / 14) {
                bestLScore = edgeCount;
                bestL = cx;
            }
        }
    }

    // 2. Magnetic Right Edge Snapping
    int bestR = right, bestRScore = 0;
    for (int dx = -snapThreshold; dx <= snapThreshold; dx++) {
        int cx = right + dx;
        if (cx > 0 && cx < imgW - 1) {
            int edgeCount = 0;
            for (int cy = top; cy <= bottom; cy += 4) {
                if (colorDiff(img.pixel(cx, cy), img.pixel(cx + 1, cy)) > 35) edgeCount++;
            }
            if (edgeCount > bestRScore && edgeCount >= (bottom - top) / 14) {
                bestRScore = edgeCount;
                bestR = cx;
            }
        }
    }

    // 3. Magnetic Top Edge Snapping
    int bestT = top, bestTScore = 0;
    for (int dy = -snapThreshold; dy <= snapThreshold; dy++) {
        int cy = top + dy;
        if (cy > 0 && cy < imgH - 1) {
            int edgeCount = 0;
            for (int cx = left; cx <= right; cx += 4) {
                if (colorDiff(img.pixel(cx, cy), img.pixel(cx, cy - 1)) > 35) edgeCount++;
            }
            if (edgeCount > bestTScore && edgeCount >= (right - left) / 14) {
                bestTScore = edgeCount;
                bestT = cy;
            }
        }
    }

    // 4. Magnetic Bottom Edge Snapping
    int bestB = bottom, bestBScore = 0;
    for (int dy = -snapThreshold; dy <= snapThreshold; dy++) {
        int cy = bottom + dy;
        if (cy > 0 && cy < imgH - 1) {
            int edgeCount = 0;
            for (int cx = left; cx <= right; cx += 4) {
                if (colorDiff(img.pixel(cx, cy), img.pixel(cx, cy + 1)) > 35) edgeCount++;
            }
            if (edgeCount > bestBScore && edgeCount >= (right - left) / 14) {
                bestBScore = edgeCount;
                bestB = cy;
            }
        }
    }

    if (bestR > bestL && bestB > bestT) {
        return QRect(bestL, bestT, bestR - bestL, bestB - bestT);
    }

    return QRect(left, top, right - left, bottom - top);
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
            bool ctrlDown = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
            bool altDown = (GetKeyState(VK_MENU) & 0x8000) != 0;
            bool winDown = (GetKeyState(VK_LWIN) & 0x8000) != 0 || (GetKeyState(VK_RWIN) & 0x8000) != 0;
            bool shiftDown = (GetKeyState(VK_SHIFT) & 0x8000) != 0;

            DWORD vk = pKbd->vkCode;

            if (vk == VK_ESCAPE) {
                s_instance->removeToolbarKeyboardHook();
                emit s_instance->requestHideToolbar();
                s_instance->cancelAction();
                return 1; // Handled
            }

            // Custom Ask Hotkey: '?' (Shift + /)
            if (shiftDown && !ctrlDown && !altDown && !winDown && vk == VK_OEM_2) {
                s_instance->removeToolbarKeyboardHook();
                emit s_instance->requestOpenCustomAsk();
                return 1; // Handled
            }

            // Process single-key actions only if no system modifiers (Ctrl/Alt/Win/Shift) are held
            if (!ctrlDown && !altDown && !winDown && !shiftDown) {
                int actionIdx = -1;
                if (vk >= '1' && vk <= '9') {
                    actionIdx = static_cast<int>(vk - '1');
                } else if (vk >= VK_NUMPAD1 && vk <= VK_NUMPAD9) {
                    actionIdx = static_cast<int>(vk - VK_NUMPAD1);
                } else if (vk == VK_RETURN) {
                    actionIdx = 0; // Default action 1 on Enter
                }

                if (actionIdx >= 0) {
                    s_instance->removeToolbarKeyboardHook();
                    emit s_instance->requestTriggerToolbarAction(actionIdx);
                    return 1; // Handled
                }

                // Custom Ask Hotkeys: '0', Numpad 0, 'T', or '/'
                if (vk == '0' || vk == VK_NUMPAD0 || vk == 'T' || vk == VK_OEM_2) {
                    s_instance->removeToolbarKeyboardHook();
                    emit s_instance->requestOpenCustomAsk();
                    return 1; // Handled
                }

                // If user pressed any other key (e.g. typing in another application), dismiss toolbar
                // and pass the key event through so user typing is not eaten!
                s_instance->removeToolbarKeyboardHook();
                emit s_instance->requestHideToolbar();
                s_instance->cancelAction();
            } else if (ctrlDown || altDown || winDown) {
                // If user uses any system hotkey elsewhere, dismiss toolbar
                s_instance->removeToolbarKeyboardHook();
                emit s_instance->requestHideToolbar();
                s_instance->cancelAction();
            }
        }
    }
    return CallNextHookEx(nullptr, nCode, wParam, lParam);
}

QString AppManager::formatPrompt(const QString& templateStr, const QString& targetType) {
    QString result = templateStr;
    QString langStr = (m_lang == "th") ? "Thai" : "English";

    // Replace ${lang} with active language
    result.replace("${lang}", langStr);
    result.replace("$lang", langStr);

    if (targetType == "text") {
        if (!m_activeSelectedText.isEmpty()) {
            if (result.contains("${input}")) {
                result.replace("${input}", m_activeSelectedText);
            } else if (result.contains("$input")) {
                result.replace("$input", m_activeSelectedText);
            } else {
                result += "\n\n" + m_activeSelectedText;
            }
        } else {
            // Clean up empty quote patterns if no text was captured
            result.replace("\"\"\" ${input} \"\"\"", "");
            result.replace("\"\"\"${input}\"\"\"", "");
            result.replace("${input}", "");
            result.replace("$input", "");
        }
    } else if (targetType == "image") {
        // For image mode, the image is attached as a file
        if (result.contains("${input}")) {
            result.replace("${input}", "the attached screenshot");
        } else if (result.contains("$input")) {
            result.replace("$input", "the attached screenshot");
        }
    } else {
        // Custom categories
        if (!m_activeSelectedText.isEmpty()) {
            if (result.contains("${input}")) {
                result.replace("${input}", m_activeSelectedText);
            } else if (result.contains("$input")) {
                result.replace("$input", m_activeSelectedText);
            } else {
                result += "\n\n" + m_activeSelectedText;
            }
        } else {
            result.replace("${input}", "the provided content");
            result.replace("$input", "the provided content");
        }
    }

    return result.trimmed();
}

QString AppManager::autoCopySelectedText() {
    DWORD initialSeq = GetClipboardSequenceNumber();

    // Standard Copy shortcut simulation via SendInput
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
    // Non-blocking responsive poll with QCoreApplication::processEvents (up to 280ms)
    for (int i = 0; i < 14; i++) {
        QThread::msleep(20);
        QCoreApplication::processEvents(QEventLoop::ExcludeUserInputEvents);

        if (GetClipboardSequenceNumber() != initialSeq) {
            for (int retry = 0; retry < 3; ++retry) {
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
                    if (!result.isEmpty()) {
                        return result.trimmed();
                    }
                }
                QThread::msleep(5);
            }
        }
    }

    return result.trimmed();
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
    if (w <= 4 || h <= 4) return;

    if (m_fullScreenPixmap.isNull()) {
        m_fullScreenPixmap = SnapshotImageProvider::instance()->getSnapshot();
    }
    if (m_fullScreenPixmap.isNull()) return;

    int px = qBound(0, x, m_fullScreenPixmap.width());
    int py = qBound(0, y, m_fullScreenPixmap.height());
    int pw = qMin(w, m_fullScreenPixmap.width() - px);
    int ph = qMin(h, m_fullScreenPixmap.height() - py);

    if (pw <= 0 || ph <= 0) return;

    QPixmap cropped = m_fullScreenPixmap.copy(px, py, pw, ph);

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

    // Compute global coordinates for toolbar placement
    m_lastCropBottomX = m_virtualOrigin.x() + px + (pw / 2);
    m_lastCropBottomY = m_virtualOrigin.y() + py + ph;

    installToolbarKeyboardHook("image");
    emit requestShowToolbar("image", m_lastCropBottomX, m_lastCropBottomY);
}

void AppManager::captureAndCopy(int x, int y, int w, int h) {
    if (w <= 2 || h <= 2) return;
    if (m_fullScreenPixmap.isNull()) {
        m_fullScreenPixmap = SnapshotImageProvider::instance()->getSnapshot();
    }
    if (m_fullScreenPixmap.isNull()) return;

    int px = qBound(0, x, m_fullScreenPixmap.width());
    int py = qBound(0, y, m_fullScreenPixmap.height());
    int pw = qMin(w, m_fullScreenPixmap.width() - px);
    int ph = qMin(h, m_fullScreenPixmap.height() - py);

    if (pw <= 0 || ph <= 0) return;

    QPixmap cropped = m_fullScreenPixmap.copy(px, py, pw, ph);

    QClipboard* clipboard = QGuiApplication::clipboard();
    if (clipboard) {
        clipboard->setPixmap(cropped);
    }
}

void AppManager::captureAndTriggerAction(int x, int y, int w, int h, int promptIndex) {
    if (w <= 2 || h <= 2) return;
    if (m_fullScreenPixmap.isNull()) {
        m_fullScreenPixmap = SnapshotImageProvider::instance()->getSnapshot();
    }
    if (m_fullScreenPixmap.isNull()) return;

    int px = qBound(0, x, m_fullScreenPixmap.width());
    int py = qBound(0, y, m_fullScreenPixmap.height());
    int pw = qMin(w, m_fullScreenPixmap.width() - px);
    int ph = qMin(h, m_fullScreenPixmap.height() - py);

    if (pw <= 0 || ph <= 0) return;

    QPixmap cropped = m_fullScreenPixmap.copy(px, py, pw, ph);

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

    triggerAction(promptIndex, "image");
}

void AppManager::captureAndTriggerCustomPrompt(int x, int y, int w, int h, const QString& customPrompt, bool autoRun) {
    if (w <= 2 || h <= 2) return;
    if (m_fullScreenPixmap.isNull()) {
        m_fullScreenPixmap = SnapshotImageProvider::instance()->getSnapshot();
    }
    if (m_fullScreenPixmap.isNull()) return;

    int px = qBound(0, x, m_fullScreenPixmap.width());
    int py = qBound(0, y, m_fullScreenPixmap.height());
    int pw = qMin(w, m_fullScreenPixmap.width() - px);
    int ph = qMin(h, m_fullScreenPixmap.height() - py);

    if (pw <= 0 || ph <= 0) return;

    QPixmap cropped = m_fullScreenPixmap.copy(px, py, pw, ph);

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

    triggerCustomPrompt(customPrompt, "image", autoRun);
}

QString AppManager::performOcr(int x, int y, int w, int h, const QString& lang) {
    if (w <= 2 || h <= 2) return QString();
    if (m_fullScreenPixmap.isNull()) {
        m_fullScreenPixmap = SnapshotImageProvider::instance()->getSnapshot();
    }
    if (m_fullScreenPixmap.isNull()) return QString();

    int px = qBound(0, x, m_fullScreenPixmap.width());
    int py = qBound(0, y, m_fullScreenPixmap.height());
    int pw = qMin(w, m_fullScreenPixmap.width() - px);
    int ph = qMin(h, m_fullScreenPixmap.height() - py);

    if (pw <= 0 || ph <= 0) return QString();

    QPixmap cropped = m_fullScreenPixmap.copy(px, py, pw, ph);
    QString recognized = OcrEngine::instance()->recognizeText(cropped, lang);
    return recognized;
}

void AppManager::copyTextToClipboard(const QString& text) {
    QClipboard* clipboard = QGuiApplication::clipboard();
    if (clipboard) {
        clipboard->setText(text);
    }
}

bool AppManager::isOcrAvailable() const {
    return OcrEngine::instance()->isAvailable();
}

QStringList AppManager::availableOcrLanguages() const {
    return OcrEngine::instance()->availableLanguages();
}

void AppManager::exitApp() {
    removeToolbarKeyboardHook();
    if (m_hotkeyHwnd) {
        unregisterGlobalHotkeys(m_hotkeyHwnd);
    }
    if (m_webViewWindow) {
        m_webViewWindow->close();
    }
    QGuiApplication::quit();
}

void AppManager::triggerAction(int index, const QString& targetType) {
    removeToolbarKeyboardHook();

    QString promptTemplate = "";

    auto getPromptFromList = [](const QVariantList& list, int idx) -> QString {
        // 1. Try enabled-filtered index first
        int enabledCount = 0;
        for (const QVariant& v : list) {
            QVariantMap item = v.toMap();
            bool isEn = item.contains("enabled") ? item.value("enabled").toBool() : true;
            if (isEn) {
                if (enabledCount == idx) {
                    return item.value("prompt").toString();
                }
                enabledCount++;
            }
        }
        // 2. Fallback to raw index if valid
        if (idx >= 0 && idx < list.size()) {
            return list[idx].toMap().value("prompt").toString();
        }
        return "";
    };

    if (targetType == "image") {
        promptTemplate = getPromptFromList(m_imagePrompts, index);
    } else if (targetType == "text") {
        promptTemplate = getPromptFromList(m_textPrompts, index);
    } else {
        for (const QVariant& catVar : m_categories) {
            QVariantMap catMap = catVar.toMap();
            if (catMap.value("id").toString() == targetType) {
                QVariantList catPrompts = catMap.value("prompts").toList();
                promptTemplate = getPromptFromList(catPrompts, index);
                break;
            }
        }
        if (promptTemplate.isEmpty()) {
            promptTemplate = getPromptFromList(m_imagePrompts, index);
        }
    }

    QString finalPrompt = formatPrompt(promptTemplate, targetType);

    if (m_webViewWindow) {
        m_webViewWindow->injectPromptAndImage(m_activeBase64Image, finalPrompt, m_autoRun);
    }
}

void AppManager::triggerCustomPrompt(const QString& customPrompt, const QString& targetType, bool autoRun) {
    removeToolbarKeyboardHook();

    QString finalPrompt = formatPrompt(customPrompt, targetType);
    if (finalPrompt.isEmpty() && !m_activeSelectedText.isEmpty()) {
        finalPrompt = m_activeSelectedText;
    }

    if (m_webViewWindow) {
        m_webViewWindow->injectPromptAndImage(m_activeBase64Image, finalPrompt, autoRun);
    }
}

void AppManager::triggerPromptDirect(const QString& promptText, const QString& targetType) {
    removeToolbarKeyboardHook();

    QString finalPrompt = formatPrompt(promptText, targetType);

    if (m_webViewWindow) {
        m_webViewWindow->injectPromptAndImage(m_activeBase64Image, finalPrompt, m_autoRun);
    }
}

void AppManager::cancelAction() {
    removeToolbarKeyboardHook();
    m_activeBase64Image.clear();
    m_activeSelectedText.clear();
    m_fullScreenPixmap = QPixmap();
    if (m_webViewWasVisible && m_webViewWindow) {
        m_webViewWindow->restoreAndShow();
        m_webViewWasVisible = false;
    }
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

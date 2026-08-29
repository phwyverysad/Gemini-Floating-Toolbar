#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <QApplication>
#include <QDir>
#include <QFileInfo>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickWindow>
#include <QIcon>
#include <QSystemTrayIcon>
#include <QCursor>
#include <QDebug>
#include "AppManager.h"
#include "WebViewWindow.h"
#include "SnapshotImageProvider.h"
#include "../resources/resource.h"

#define SINGLE_INSTANCE_MUTEX L"GoogleGeminiQtSingleInstanceMutex"
#define HOTKEY_HELPER_CLASS L"GeminiHotkeyHelperWndClass"

#ifndef ID_TRAY_LANG_TOGGLE
#define ID_TRAY_LANG_TOGGLE 1014
#endif

static HWND g_hHotkeyHelper = nullptr;

static LRESULT CALLBACK HotkeyHelperWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == WM_HOTKEY) {
        AppManager::instance()->handleGlobalHotkey(static_cast<int>(wParam));
        return 0;
    }
    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

static HWND CreateHotkeyHelperWindow(HINSTANCE hInstance) {
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(WNDCLASSEXW);
    wc.lpfnWndProc = HotkeyHelperWndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = HOTKEY_HELPER_CLASS;
    RegisterClassExW(&wc);

    return CreateWindowExW(
        0, HOTKEY_HELPER_CLASS, L"GeminiHotkeyHelper",
        0, 0, 0, 0, 0,
        HWND_MESSAGE, nullptr, hInstance, nullptr
    );
}

int main(int argc, char* argv[]) {
    // 1. Single Instance Check
    HANDLE hMutex = CreateMutexW(nullptr, TRUE, SINGLE_INSTANCE_MUTEX);
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        HWND hExisting = FindWindowExW(nullptr, nullptr, L"GeminiWebViewHostClass", L"Google Gemini");
        if (hExisting) {
            ShowWindow(hExisting, SW_RESTORE);
            SetForegroundWindow(hExisting);
        }
        if (hMutex) CloseHandle(hMutex);
        return 0;
    }

    // Explicitly configure Qt plugin library paths relative to executable
    wchar_t exePathBuffer[MAX_PATH];
    GetModuleFileNameW(nullptr, exePathBuffer, MAX_PATH);
    QString appDirPath = QFileInfo(QString::fromWCharArray(exePathBuffer)).absolutePath();
    QCoreApplication::addLibraryPath(appDirPath);
    QCoreApplication::addLibraryPath(appDirPath + "/platforms");

    // 2. Initialize Qt Application
    QApplication app(argc, argv);
    app.setApplicationName("Google Gemini");
    app.setOrganizationName("Antigravity");
    app.setApplicationVersion("1.0.0");
    app.setQuitOnLastWindowClosed(false);

    HINSTANCE hInstance = GetModuleHandle(nullptr);

    // 3. Initialize WebView2 Host Window
    WebViewWindow webViewWindow;
    if (!webViewWindow.initialize(hInstance)) {
        qWarning() << "Failed to initialize WebView2 window";
    }

    // 4. Initialize Hotkey Helper Window & AppManager
    g_hHotkeyHelper = CreateHotkeyHelperWindow(hInstance);
    AppManager* appManager = AppManager::instance();
    appManager->setWebViewWindow(&webViewWindow);
    appManager->registerGlobalHotkeys(g_hHotkeyHelper);

    // 5. Initialize QML Engine & Components
    QQmlApplicationEngine engine;
    engine.addImageProvider("snapshot", SnapshotImageProvider::instance());
    engine.rootContext()->setContextProperty("AppManager", appManager);
    engine.addImportPath("qrc:/");
    engine.addImportPath("qrc:/qml");

    // Load QML Views via QQmlComponent
    QQmlComponent toolbarComp(&engine, QUrl("qrc:/qml/FloatingToolbar.qml"));
    QObject* floatingToolbarObj = toolbarComp.create();
    if (!floatingToolbarObj) {
        qCritical() << "Failed to create FloatingToolbar:" << toolbarComp.errors();
    }

    QQmlComponent settingsComp(&engine, QUrl("qrc:/qml/SettingsDialog.qml"));
    QObject* settingsDialogObj = settingsComp.create();
    if (!settingsDialogObj) {
        qCritical() << "Failed to create SettingsDialog:" << settingsComp.errors();
    }

    QQmlComponent snipComp(&engine, QUrl("qrc:/qml/SnippingOverlay.qml"));
    QObject* snippingOverlayObj = snipComp.create();
    if (!snippingOverlayObj) {
        qCritical() << "Failed to create SnippingOverlay:" << snipComp.errors();
    }

    // Connect C++ AppManager Signals to QML Methods
    if (snippingOverlayObj) {
        QObject::connect(appManager, &AppManager::requestShowSnipping, snippingOverlayObj, [snippingOverlayObj]() {
            QMetaObject::invokeMethod(snippingOverlayObj, "startSnipping");
        });
    }

    if (floatingToolbarObj) {
        QObject::connect(appManager, &AppManager::requestShowToolbar, floatingToolbarObj, [floatingToolbarObj](const QString& type, int x, int y) {
            QMetaObject::invokeMethod(floatingToolbarObj, "showToolbar", Q_ARG(QVariant, type), Q_ARG(QVariant, x), Q_ARG(QVariant, y));
        });
    }

    if (settingsDialogObj) {
        QObject::connect(appManager, &AppManager::requestShowSettings, settingsDialogObj, [settingsDialogObj]() {
            QMetaObject::invokeMethod(settingsDialogObj, "openDialog");
        });
    }

    // 6. Setup Pure Native Win32 Tray Context Menu (Exact Google AI Studio Architecture)
    auto showNativeWin32TrayMenu = [&]() {
        POINT pt;
        if (GetCursorPos(&pt)) {
            HMENU hMenu = CreatePopupMenu();
            bool isTh = appManager->isThai();
            QJsonObject cfg = appManager->getSettings();
            bool startWithWindows = cfg.value("startWithWindows").toBool(false);

            InsertMenuW(hMenu, -1, MF_BYPOSITION | MF_STRING, ID_TRAY_OPEN, isTh ? L"เปิด Google Gemini" : L"Open Google Gemini");
            InsertMenuW(hMenu, -1, MF_BYPOSITION | MF_STRING, ID_TRAY_SCREENSHOT, isTh ? L"แคปหน้าจอถาม Gemini" : L"Capture Screen");
            InsertMenuW(hMenu, -1, MF_BYPOSITION | MF_STRING, ID_TRAY_QUICKASK, isTh ? L"คลุมข้อความถาม Gemini" : L"Quick Ask Gemini");
            InsertMenuW(hMenu, -1, MF_BYPOSITION | MF_SEPARATOR, 0, nullptr);

            InsertMenuW(hMenu, -1, MF_BYPOSITION | MF_STRING, ID_TRAY_SETTINGS, isTh ? L"ตั้งค่าปุ่มลัดและคำสั่งด่วน" : L"Settings & Hotkeys");
            InsertMenuW(hMenu, -1, MF_BYPOSITION | MF_STRING, ID_TRAY_LANG_TOGGLE, isTh ? L"ภาษา / Language (ไทย)" : L"Language / ภาษา (EN)");
            
            UINT startupFlags = MF_BYPOSITION | MF_STRING | (startWithWindows ? MF_CHECKED : MF_UNCHECKED);
            InsertMenuW(hMenu, -1, startupFlags, ID_TRAY_STARTUP_TOGGLE, isTh ? L"เปิดโปรแกรมพร้อม Windows" : L"Start with Windows");

            InsertMenuW(hMenu, -1, MF_BYPOSITION | MF_SEPARATOR, 0, nullptr);
            InsertMenuW(hMenu, -1, MF_BYPOSITION | MF_STRING, ID_TRAY_EXIT, isTh ? L"ออกจากโปรแกรม" : L"Exit");

            SetMenuDefaultItem(hMenu, ID_TRAY_OPEN, FALSE);

            SetForegroundWindow(g_hHotkeyHelper);
            int cmd = TrackPopupMenu(hMenu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_BOTTOMALIGN | TPM_LEFTALIGN, pt.x, pt.y, 0, g_hHotkeyHelper, nullptr);
            PostMessage(g_hHotkeyHelper, WM_NULL, 0, 0);
            DestroyMenu(hMenu);

            switch (cmd) {
            case ID_TRAY_OPEN:
                webViewWindow.show();
                break;
            case ID_TRAY_SCREENSHOT:
                appManager->startSnipping();
                break;
            case ID_TRAY_QUICKASK:
                appManager->startQuickAskFlow();
                break;
            case ID_TRAY_SETTINGS:
                appManager->showSettingsDialog();
                break;
            case ID_TRAY_LANG_TOGGLE:
                appManager->setLanguage(isTh ? "en" : "th");
                break;
            case ID_TRAY_STARTUP_TOGGLE: {
                QJsonObject c = appManager->getSettings();
                c["startWithWindows"] = !startWithWindows;
                appManager->saveSettings(c);
                break;
            }
            case ID_TRAY_EXIT:
                appManager->exitApp();
                break;
            }
        }
    };

    QSystemTrayIcon trayIcon;
    QIcon appIcon = QIcon("gemini-color.png");
    trayIcon.setIcon(appIcon);
    trayIcon.setToolTip("Google Gemini Desktop");

    QObject::connect(&trayIcon, &QSystemTrayIcon::activated, [&webViewWindow, &showNativeWin32TrayMenu](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::DoubleClick) {
            webViewWindow.toggle();
        } else if (reason == QSystemTrayIcon::Context) {
            showNativeWin32TrayMenu();
        }
    });

    trayIcon.show();

    // 7. Initial Window Visibility
    bool startMinimized = false;
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--minimized") == 0 || strcmp(argv[i], "-minimized") == 0) {
            startMinimized = true;
            break;
        }
    }

    if (!startMinimized) {
        webViewWindow.show();
    }

    int execResult = app.exec();

    if (g_hHotkeyHelper) {
        DestroyWindow(g_hHotkeyHelper);
        g_hHotkeyHelper = nullptr;
    }
    if (hMutex) {
        ReleaseMutex(hMutex);
        CloseHandle(hMutex);
    }

    return execResult;
}

#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QPixmap>
#include <QImage>
#include <QGuiApplication>
#include <QScreen>
#include <QBuffer>
#include <QByteArray>
#include <windows.h>

class WebViewWindow;

class AppManager : public QObject {
    Q_OBJECT

    // QML Properties
    Q_PROPERTY(bool isThai READ isThai NOTIFY settingsChanged)
    Q_PROPERTY(QString currentTheme READ currentTheme NOTIFY settingsChanged)
    Q_PROPERTY(QString toolbarPlacement READ toolbarPlacement NOTIFY settingsChanged)
    Q_PROPERTY(QString toolbarSize READ toolbarSize NOTIFY settingsChanged)
    Q_PROPERTY(int toolbarHeight READ toolbarHeight NOTIFY settingsChanged)
    Q_PROPERTY(QJsonObject cancelButton READ cancelButton NOTIFY settingsChanged)
    Q_PROPERTY(QVariantList imagePrompts READ imagePrompts NOTIFY settingsChanged)
    Q_PROPERTY(QVariantList textPrompts READ textPrompts NOTIFY settingsChanged)
    Q_PROPERTY(QVariantList categories READ categories NOTIFY settingsChanged)

public:
    static AppManager* instance();
    explicit AppManager(QObject* parent = nullptr);
    ~AppManager();

    bool isThai() const { return m_lang == "th"; }
    QString currentTheme() const { return m_theme; }
    QString toolbarPlacement() const { return m_placement; }
    QString toolbarSize() const { return m_toolbarSize; }
    int toolbarHeight() const { return m_toolbarHeight; }
    QJsonObject cancelButton() const { return m_cancelButton; }
    QVariantList imagePrompts() const { return m_imagePrompts; }
    QVariantList textPrompts() const { return m_textPrompts; }
    QVariantList categories() const { return m_categories; }

    void setWebViewWindow(WebViewWindow* webView) { m_webViewWindow = webView; }

    // Settings Operations (Invokable from QML)
    Q_INVOKABLE QJsonObject getSettings();
    Q_INVOKABLE void saveSettings(const QJsonObject& json);
    Q_INVOKABLE void resetDefaults();
    Q_INVOKABLE void setLanguage(const QString& lang);
    Q_INVOKABLE void setToolbarPlacement(const QString& placement);
    Q_INVOKABLE void setToolbarHeight(int h);

    // Action Triggers (Invokable from QML)
    Q_INVOKABLE void startSnipping();
    Q_INVOKABLE void processScreenCrop(int x, int y, int w, int h);
    Q_INVOKABLE void triggerAction(int index, const QString& targetType);
    Q_INVOKABLE void triggerCustomPrompt(const QString& customPrompt, const QString& targetType);
    Q_INVOKABLE void triggerPromptDirect(const QString& promptText, const QString& targetType);
    Q_INVOKABLE void cancelAction();
    Q_INVOKABLE void previewToolbar(int heightVal = 0, const QString& targetType = "image");

    // UI Window Navigation (Invokable from QML / Tray)
    Q_INVOKABLE void showSettingsDialog();
    Q_INVOKABLE void hideSettingsDialog();
    Q_INVOKABLE void toggleMainWindow();
    Q_INVOKABLE void exitApp();

    // Hotkey Management
    void registerGlobalHotkeys(HWND hWnd);
    void unregisterGlobalHotkeys(HWND hWnd);
    void handleGlobalHotkey(int hotkeyId);

    // Native helpers
    void startQuickAskFlow();
    QString autoCopySelectedText();

    void installToolbarKeyboardHook(const QString& targetType);
    void removeToolbarKeyboardHook();
    static LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam);

signals:
    void settingsChanged();
    void requestShowSnipping();
    void requestShowToolbar(const QString& type, int x, int y);
    void requestHideToolbar();
    void requestShowSettings();

private:
    void loadSettingsFromFile();
    void saveSettingsToFile();
    void applyStartupRegistry(bool enable);
    QJsonObject getDefaultSettingsJson();

    static AppManager* s_instance;
    WebViewWindow* m_webViewWindow = nullptr;
    HWND m_hotkeyHwnd = nullptr;
    HHOOK m_toolbarKbdHook = nullptr;
    QString m_activeToolbarType = "image";

    QString m_lang = "th";
    QString m_theme = "light";
    QString m_placement = "auto";
    QString m_toolbarSize = "normal";
    int m_toolbarHeight = 38;
    QJsonObject m_cancelButton;

    QJsonObject m_toggleHotkey;
    QJsonObject m_snipHotkey;
    QJsonObject m_quickAskHotkey;

    QVariantList m_imagePrompts;
    QVariantList m_textPrompts;
    QVariantList m_categories;
    QJsonObject m_promptsMap;

    bool m_autoRun = true;
    bool m_startWithWindows = false;

    // Active payload for execution
    QPixmap m_fullScreenPixmap;
    QString m_activeBase64Image;
    QString m_activeSelectedText;
    int m_lastCropBottomX = 0;
    int m_lastCropBottomY = 0;
};

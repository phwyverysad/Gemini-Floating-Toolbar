#pragma once

#include <windows.h>
#include <wrl.h>
#include <string>
#include <QString>
#include "WebView2.h"

using namespace Microsoft::WRL;

class WebViewWindow {
public:
    WebViewWindow();
    ~WebViewWindow();

    bool initialize(HINSTANCE hInstance);
    void show();
    void hide();
    void toggle();
    void restoreAndShow();
    HWND getHwnd() const { return m_hWnd; }

    void injectPromptAndImage(const QString& base64Image, const QString& promptText, bool autoRun);

private:
    static LRESULT CALLBACK s_wndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
    LRESULT wndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
    void initWebView();
    void resizeWebView();
    std::wstring getUserDataFolder();

    HINSTANCE m_hInstance = nullptr;
    HWND m_hWnd = nullptr;
    ComPtr<ICoreWebView2Environment> m_webViewEnv;
    ComPtr<ICoreWebView2Controller> m_webController;
    ComPtr<ICoreWebView2> m_webView;
};

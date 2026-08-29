#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <sstream>
#include <QJsonObject>
#include <QJsonDocument>
#include "WebViewWindow.h"
#include "../resources/resource.h"

#pragma comment(lib, "shlwapi.lib")

#define GEMINI_URL L"https://gemini.google.com/app"
#define WINDOW_CLASS_NAME L"GeminiWebViewHostClass"

WebViewWindow::WebViewWindow() {
}

WebViewWindow::~WebViewWindow() {
    close();
}

void WebViewWindow::close() {
    if (m_webController) {
        m_webController->Close();
        m_webController = nullptr;
    }
    m_webView = nullptr;
    m_webViewEnv = nullptr;
    if (m_hWnd) {
        DestroyWindow(m_hWnd);
        m_hWnd = nullptr;
    }
}

std::wstring WebViewWindow::getUserDataFolder() {
    wchar_t localAppData[MAX_PATH] = { 0 };
    GetEnvironmentVariableW(L"LOCALAPPDATA", localAppData, MAX_PATH);
    std::wstring folder = std::wstring(localAppData) + L"\\Gemini\\UserData";
    SHCreateDirectoryExW(nullptr, folder.c_str(), nullptr);
    return folder;
}

bool WebViewWindow::initialize(HINSTANCE hInstance) {
    m_hInstance = hInstance;

    WNDCLASSEXW wcex = {};
    wcex.cbSize = sizeof(WNDCLASSEXW);
    wcex.style = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc = s_wndProc;
    wcex.hInstance = hInstance;
    wcex.hIcon = LoadIconW(hInstance, MAKEINTRESOURCEW(IDI_APP_ICON));
    wcex.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wcex.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    wcex.lpszClassName = WINDOW_CLASS_NAME;
    wcex.hIconSm = LoadIconW(hInstance, MAKEINTRESOURCEW(IDI_APP_ICON));

    RegisterClassExW(&wcex);

    int screenW = GetSystemMetrics(SM_CXSCREEN);
    int screenH = GetSystemMetrics(SM_CYSCREEN);
    int w = 1100;
    int h = 820;
    int x = (screenW - w) / 2;
    int y = (screenH - h) / 2;

    m_hWnd = CreateWindowExW(
        WS_EX_APPWINDOW,
        WINDOW_CLASS_NAME,
        L"Google Gemini",
        WS_OVERLAPPEDWINDOW,
        x, y, w, h,
        nullptr, nullptr, hInstance, this
    );

    if (!m_hWnd) return false;

    initWebView();
    return true;
}

void WebViewWindow::initWebView() {
    std::wstring userDataFolder = getUserDataFolder();

    CreateCoreWebView2EnvironmentWithOptions(
        nullptr,
        userDataFolder.c_str(),
        nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [this](HRESULT result, ICoreWebView2Environment* env) -> HRESULT {
                if (FAILED(result) || !env) return result;
                m_webViewEnv = env;

                m_webViewEnv->CreateCoreWebView2Controller(
                    m_hWnd,
                    Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                        [this](HRESULT res, ICoreWebView2Controller* controller) -> HRESULT {
                            if (FAILED(res) || !controller) return res;

                            m_webController = controller;
                            m_webController->get_CoreWebView2(&m_webView);

                            RECT bounds;
                            GetClientRect(m_hWnd, &bounds);
                            m_webController->put_Bounds(bounds);
                            m_webController->put_IsVisible(TRUE);

                            ComPtr<ICoreWebView2Settings> settings;
                            if (SUCCEEDED(m_webView->get_Settings(&settings)) && settings) {
                                settings->put_IsScriptEnabled(TRUE);
                                settings->put_AreDefaultScriptDialogsEnabled(TRUE);
                                settings->put_IsWebMessageEnabled(TRUE);
                                settings->put_AreDevToolsEnabled(FALSE);
                                settings->put_IsStatusBarEnabled(FALSE);
                                settings->put_AreDefaultContextMenusEnabled(TRUE);
                                settings->put_IsZoomControlEnabled(TRUE);

                                ComPtr<ICoreWebView2Settings2> settings2;
                                if (SUCCEEDED(settings.As(&settings2)) && settings2) {
                                    settings2->put_UserAgent(L"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36");
                                }
                            }

                            // Hardware-level Enter keystroke simulation via WebMessage
                            m_webView->add_WebMessageReceived(
                                Callback<ICoreWebView2WebMessageReceivedEventHandler>(
                                    [this](ICoreWebView2* sender, ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT {
                                        LPWSTR message = nullptr;
                                        if (SUCCEEDED(args->TryGetWebMessageAsString(&message)) && message) {
                                            std::wstring msg = message;
                                            CoTaskMemFree(message);
                                            if (msg == L"TRIGGER_ENTER_KEY") {
                                                if (m_webController) {
                                                    m_webController->MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC);
                                                }
                                                INPUT inputs[2] = {};
                                                inputs[0].type = INPUT_KEYBOARD;
                                                inputs[0].ki.wVk = VK_RETURN;
                                                inputs[1].type = INPUT_KEYBOARD;
                                                inputs[1].ki.wVk = VK_RETURN;
                                                inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;
                                                SendInput(2, inputs, sizeof(INPUT));
                                            }
                                        }
                                        return S_OK;
                                    }
                                ).Get(),
                                nullptr
                            );

                            m_webView->Navigate(GEMINI_URL);
                            return S_OK;
                        }
                    ).Get()
                );
                return S_OK;
            }
        ).Get()
    );
}

void WebViewWindow::resizeWebView() {
    if (m_webController && m_hWnd) {
        RECT bounds;
        GetClientRect(m_hWnd, &bounds);
        m_webController->put_Bounds(bounds);
    }
}

void WebViewWindow::show() {
    if (m_hWnd) {
        ShowWindow(m_hWnd, SW_SHOW);
        SetForegroundWindow(m_hWnd);
        resizeWebView();
    }
}

void WebViewWindow::hide() {
    if (m_hWnd) {
        ShowWindow(m_hWnd, SW_HIDE);
    }
}

void WebViewWindow::toggle() {
    if (m_hWnd) {
        if (IsWindowVisible(m_hWnd) && !IsIconic(m_hWnd)) {
            hide();
        } else {
            restoreAndShow();
        }
    }
}

void WebViewWindow::restoreAndShow() {
    if (m_hWnd) {
        if (IsIconic(m_hWnd)) {
            ShowWindow(m_hWnd, SW_RESTORE);
        } else {
            ShowWindow(m_hWnd, SW_SHOW);
        }
        SetForegroundWindow(m_hWnd);
        resizeWebView();
    }
}

void WebViewWindow::injectPromptAndImage(const QString& base64Image, const QString& promptText, bool autoRun) {
    if (!m_webView) return;

    restoreAndShow();

    QJsonObject payloadObj;
    payloadObj["base64"] = base64Image;
    payloadObj["prompt"] = promptText;
    payloadObj["autoRun"] = autoRun;
    QString jsonStr = QString::fromUtf8(QJsonDocument(payloadObj).toJson(QJsonDocument::Compact));
    std::wstring configJson = jsonStr.toStdWString();

    std::wstring jsCode = LR"JS(
(function() {
    if (window.__lastInjectTime && (Date.now() - window.__lastInjectTime < 300)) return;
    window.__lastInjectTime = Date.now();

    const config = )JS" + configJson + LR"JS(;
    const base64Data = config.base64 || "";
    const promptText = config.prompt || "";
    const shouldSubmit = !!config.autoRun;
    const uniqueFileName = 'screenshot_' + Date.now() + '.png';

    function base64ToFile(base64, filename) {
        try {
            const byteCharacters = atob(base64);
            const byteArrays = [];
            const sliceSize = 1024;
            for (let offset = 0; offset < byteCharacters.length; offset += sliceSize) {
                const slice = byteCharacters.slice(offset, offset + sliceSize);
                const byteNumbers = new Array(slice.length);
                for (let i = 0; i < slice.length; i++) {
                    byteNumbers[i] = slice.charCodeAt(i);
                }
                const byteArray = new Uint8Array(byteNumbers);
                byteArrays.push(byteArray);
            }
            const blob = new Blob(byteArrays, { type: 'image/png' });
            return new File([blob], filename, { type: 'image/png', lastModified: Date.now() });
        } catch(e) {
            return null;
        }
    }

    function findPromptInput() {
        const candidates = [
            'rich-textarea [contenteditable="true"]',
            'div[contenteditable="true"]',
            'rich-textarea div p',
            '.ql-editor',
            'div.ql-editor[contenteditable="true"]',
            'div.ql-editor.textarea',
            'textarea.textarea',
            'textarea',
            '[role="textbox"]',
            '[role="combobox"]',
            '[aria-label*="Ask Gemini" i]',
            '[aria-label*="ถาม Gemini" i]',
            '[placeholder*="Ask Gemini" i]',
            '[placeholder*="ถาม Gemini" i]',
            '[aria-label*="Enter a prompt" i]',
            '[aria-label*="ป้อนข้อความแจ้ง" i]',
            '[aria-label*="ป้อนพรอมต์" i]',
            '[aria-label*="Prompt" i]',
            '[aria-label*="Type something" i]',
            '[placeholder*="Type something" i]'
        ];

        for (const sel of candidates) {
            const list = Array.from(document.querySelectorAll(sel));
            const found = list.find(el => el.offsetParent !== null && !el.disabled);
            if (found) return found;
        }
        return null;
    }

    function injectText(el, text) {
        if (!el || !text) return;
        el.focus();

        if (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT') {
            el.value = text;
            el.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
            el.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
        } else {
            try {
                document.execCommand('selectAll', false, null);
                document.execCommand('insertText', false, text);
            } catch(e) {
                el.innerText = text;
                el.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
            }
        }
    }

    function attachImage(file, targetEl) {
        if (!file) return false;

        const dt = new DataTransfer();
        dt.items.add(file);

        // 1. Target input[type="file"]
        const fileInput = document.querySelector('input[type="file"]');
        if (fileInput) {
            try {
                fileInput.files = dt.files;
                fileInput.dispatchEvent(new Event('change', { bubbles: true, composed: true }));
                fileInput.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
            } catch(e) {}
        }

        // 2. Dispatch Paste Event
        try {
            const pasteEvt = new ClipboardEvent('paste', {
                bubbles: true,
                cancelable: true,
                composed: true,
                clipboardData: dt
            });
            const target = targetEl || document.activeElement || document.body;
            target.dispatchEvent(pasteEvt);
        } catch(e) {}

        // 3. Dispatch Drop Event
        try {
            const dropEvt = new DragEvent('drop', {
                bubbles: true,
                cancelable: true,
                composed: true,
                dataTransfer: dt
            });
            (targetEl || document.body).dispatchEvent(dropEvt);
        } catch(e) {}

        return true;
    }

    function isSendButton(btn) {
        if (!btn || btn.offsetParent === null || btn.disabled || btn.getAttribute('aria-disabled') === 'true') return false;
        const aria = (btn.getAttribute('aria-label') || '').toLowerCase();
        const testId = (btn.getAttribute('data-test-id') || '').toLowerCase();
        const className = (btn.className || '').toLowerCase();
        const text = (btn.innerText || '').trim().toLowerCase();

        // Disqualify unrelated buttons
        const badKeywords = [
            'mic', 'audio', 'voice', 'ไมค์', 'ไมโครโฟน',
            'upload', 'attach', 'file', 'แนบ', 'ไฟล์', 'image', 'รูปภาพ',
            'menu', 'เมนู', 'history', 'ประวัติ', 'settings', 'ตั้งค่า',
            'help', 'ช่วยเหลือ', 'account', 'บัญชี', 'profile', 'โปรไฟล์',
            'model', 'tools', 'เครื่องมือ', 'sidebar', 'ไซด์บาร์',
            'collapse', 'expand', 'more', 'เพิ่มเติม', 'delete', 'ลบ'
        ];
        for (const bad of badKeywords) {
            if (aria.includes(bad) || testId.includes(bad)) return false;
        }

        // Positive Send / Submit identifiers
        if (aria.includes('send') || aria.includes('ส่ง') || aria.includes('submit') || aria.includes('run') || aria.includes('พร้อมท์')) return true;
        if (testId.includes('send') || testId.includes('submit')) return true;
        if (className.includes('send-button') || className.includes('send_button') || className.includes('chatsendbutton')) return true;
        if (text === 'send' || text === 'ส่ง' || text === 'run') return true;
        return false;
    }

    function findSendButton(inputEl) {
        // 1. First search inside the closest input container
        if (inputEl) {
            let container = inputEl.closest('rich-textarea, .input-area, .chat-input, .text-input-field, form, .input-container, .bottom-container, .input-area-container') || inputEl.parentElement;
            for (let depth = 0; depth < 6 && container; depth++) {
                const candidates = Array.from(container.querySelectorAll('button'));
                const found = candidates.find(b => isSendButton(b));
                if (found) return found;
                container = container.parentElement;
            }
        }

        // 2. Specific known Gemini send button selectors
        const geminiSelectors = [
            'button.send-button',
            'button[aria-label*="Send message" i]',
            'button[aria-label*="ส่งข้อความ" i]',
            'button[aria-label="Send" i]',
            'button[aria-label="ส่ง" i]',
            'button[aria-label*="Submit" i]',
            'button[data-test-id="send-button"]',
            'button[data-test-id*="send"]',
            'button[mattooltip*="Send" i]',
            'button[mattooltip*="ส่ง" i]',
            '.send-button-container button',
            'button.chat-send-button'
        ];
        for (const sel of geminiSelectors) {
            const list = Array.from(document.querySelectorAll(sel));
            const found = list.find(b => isSendButton(b));
            if (found) return found;
        }

        // 3. Scoped search near bottom of page
        const allButtons = Array.from(document.querySelectorAll('button'));
        for (let i = allButtons.length - 1; i >= 0; i--) {
            if (isSendButton(allButtons[i])) return allButtons[i];
        }
        return null;
    }

    function pressEnterKey(inputEl) {
        try {
            if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
                window.chrome.webview.postMessage("TRIGGER_ENTER_KEY");
            }
        } catch(e) {}
        if (!inputEl) return;
        try {
            const downEvt = new KeyboardEvent('keydown', {
                key: 'Enter',
                code: 'Enter',
                keyCode: 13,
                which: 13,
                bubbles: true,
                cancelable: true,
                composed: true
            });
            inputEl.dispatchEvent(downEvt);

            const upEvt = new KeyboardEvent('keyup', {
                key: 'Enter',
                code: 'Enter',
                keyCode: 13,
                which: 13,
                bubbles: true,
                cancelable: true,
                composed: true
            });
            inputEl.dispatchEvent(upEvt);
        } catch(e) {}
    }

    function performInjection() {
        const el = findPromptInput();
        if (!el) return false;

        el.focus();

        const file = (base64Data && base64Data.length > 10) ? base64ToFile(base64Data, uniqueFileName) : null;
        const container = el.closest('rich-textarea, .input-area, .chat-input, .text-input-field, form, .input-container, .bottom-container, .input-area-container') || el.parentElement;

        if (file) {
            // Count existing attachment cards strictly inside the input container
            const initialCardCount = container ? container.querySelectorAll('.attachment-card, .attachment-container, .image-preview, .uploader-preview, mat-chip, [aria-label*="Remove" i], [aria-label*="Delete" i], [aria-label*="ลบ" i], img').length : 0;
            const attachStartTime = Date.now();

            // 1. Attach the image file FIRST
            attachImage(file, el);

            // 2. Inject prompt text
            injectText(el, promptText);

            if (!shouldSubmit) return true;

            // 3. Strict Synchronized Submit: Wait until image is 100% attached and uploaded
            let pollCount = 0;
            const maxPoll = 480; // 12.0 seconds maximum wait
            let sent = false;
            let cardAppeared = false;

            function isContainerUploading() {
                if (!container) return false;
                const spinners = container.querySelectorAll('mat-progress-spinner, mat-spinner, .mat-mdc-progress-spinner, .loading, .uploading, [role="progressbar"]');
                return Array.from(spinners).some(s => s.offsetParent !== null);
            }

            function hasNewContainerAttachment() {
                if (!container) return false;
                const currentCards = container.querySelectorAll('.attachment-card, .attachment-container, .image-preview, .uploader-preview, mat-chip, [aria-label*="Remove" i], [aria-label*="Delete" i], [aria-label*="ลบ" i], img');
                return (currentCards.length > initialCardCount) || (currentCards.length > 0 && (Date.now() - attachStartTime > 350));
            }

            function trySynchronizedSubmit() {
                if (sent) return true;

                // Step A: Must wait for attachment card to appear inside input container
                if (!cardAppeared) {
                    if (hasNewContainerAttachment()) {
                        cardAppeared = true;
                    } else {
                        return false; // Waiting for paste/upload card creation
                    }
                }

                // Step B: Must wait for all upload spinners to disappear
                if (isContainerUploading()) {
                    return false; // Still actively uploading image bytes
                }

                // Step C: Must verify Send button is enabled
                const runBtn = findSendButton(el);
                const isBtnEnabled = runBtn && !runBtn.disabled && runBtn.getAttribute('aria-disabled') !== 'true';
                if (!isBtnEnabled) {
                    return false; // Waiting for Gemini to enable send button
                }

                // Step D: Ensure prompt text is still in the input field
                const currentText = el.innerText || el.value || '';
                if (promptText && !currentText.includes(promptText.trim())) {
                    injectText(el, promptText);
                }

                // Step E: Send both Image & Prompt simultaneously!
                sent = true;
                runBtn.click();
                setTimeout(() => { pressEnterKey(el); }, 80);
                return true;
            }

            // High-frequency 25ms polling
            const pollTimer = setInterval(() => {
                pollCount++;
                if (trySynchronizedSubmit() || pollCount >= maxPoll) {
                    clearInterval(pollTimer);
                    if (observer) observer.disconnect();
                }
            }, 25);

            // Reactive DOM mutation observer
            let observer = null;
            try {
                observer = new MutationObserver(() => {
                    if (trySynchronizedSubmit()) {
                        clearInterval(pollTimer);
                        observer.disconnect();
                    }
                });
                observer.observe(container || document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['disabled', 'aria-disabled', 'class', 'src'] });
            } catch(e) {}

        } else {
            // Text-only mode: direct injection and fast submit
            injectText(el, promptText);

            if (shouldSubmit) {
                let pollCount = 0;
                const pollTimer = setInterval(() => {
                    pollCount++;
                    const runBtn = findSendButton(el);
                    const isBtnEnabled = runBtn && !runBtn.disabled && runBtn.getAttribute('aria-disabled') !== 'true';
                    if ((isBtnEnabled && pollCount >= 2) || pollCount >= 80) {
                        clearInterval(pollTimer);
                        if (runBtn) {
                            runBtn.click();
                            setTimeout(() => { pressEnterKey(el); }, 60);
                        } else {
                            pressEnterKey(el);
                        }
                    }
                }, 25);
            }
        }

        return true;
    }

    if (!performInjection()) {
        let attempts = 0;
        const retryTimer = setInterval(() => {
            attempts++;
            if (performInjection() || attempts >= 45) {
                clearInterval(retryTimer);
            }
        }, 80);
    }
})();
)JS";

    m_webView->ExecuteScript(jsCode.c_str(), nullptr);
}

LRESULT CALLBACK WebViewWindow::s_wndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    WebViewWindow* pThis = nullptr;
    if (msg == WM_NCCREATE) {
        CREATESTRUCTW* pCreate = reinterpret_cast<CREATESTRUCTW*>(lParam);
        pThis = reinterpret_cast<WebViewWindow*>(pCreate->lpCreateParams);
        SetWindowLongPtrW(hWnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(pThis));
        pThis->m_hWnd = hWnd;
    } else {
        pThis = reinterpret_cast<WebViewWindow*>(GetWindowLongPtrW(hWnd, GWLP_USERDATA));
    }

    if (pThis) {
        return pThis->wndProc(hWnd, msg, wParam, lParam);
    }
    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

LRESULT WebViewWindow::wndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_SIZE:
        resizeWebView();
        break;

    case WM_CLOSE:
        // Minimize to background instead of quitting
        hide();
        return 0;

    default:
        return DefWindowProcW(hWnd, msg, wParam, lParam);
    }
    return 0;
}

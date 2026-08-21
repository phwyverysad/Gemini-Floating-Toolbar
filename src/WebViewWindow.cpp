#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <sstream>
#include "WebViewWindow.h"
#include "../resources/resource.h"

#pragma comment(lib, "shlwapi.lib")

#define GEMINI_URL L"https://gemini.google.com/app"
#define WINDOW_CLASS_NAME L"GeminiWebViewHostClass"

WebViewWindow::WebViewWindow() {
}

WebViewWindow::~WebViewWindow() {
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
                                                Sleep(30);
                                                keybd_event(VK_RETURN, 0, 0, 0);
                                                Sleep(15);
                                                keybd_event(VK_RETURN, 0, KEYEVENTF_KEYUP, 0);
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

static std::wstring EscapeJs(const std::wstring& input) {
    std::wostringstream ss;
    for (wchar_t c : input) {
        switch (c) {
        case L'\\': ss << L"\\\\"; break;
        case L'"': ss << L"\\\""; break;
        case L'/': ss << L"\\/"; break;
        case L'\b': ss << L"\\b"; break;
        case L'\f': ss << L"\\f"; break;
        case L'\n': ss << L"\\n"; break;
        case L'\r': ss << L"\\r"; break;
        case L'\t': ss << L"\\t"; break;
        default:
            if (c >= 0 && c <= 0x1f) {
                wchar_t buf[8];
                swprintf_s(buf, L"\\u%04x", c);
                ss << buf;
            } else {
                ss << c;
            }
            break;
        }
    }
    return ss.str();
}

void WebViewWindow::injectPromptAndImage(const QString& base64Image, const QString& promptText, bool autoRun) {
    if (!m_webView) return;

    restoreAndShow();

    std::wstring base64Str = base64Image.toStdWString();
    std::wstring promptStr = EscapeJs(promptText.toStdWString());
    std::wstring autoRunBoolStr = autoRun ? L"true" : L"false";

    std::wstring jsCode = LR"JS(
(function() {
    if (window.__lastInjectTime && (Date.now() - window.__lastInjectTime < 300)) return;
    window.__lastInjectTime = Date.now();

    const base64Data = ")JS" + base64Str + LR"JS(";
    const promptText = ")JS" + promptStr + LR"JS(";
    const shouldSubmit = )JS" + autoRunBoolStr + LR"JS(;
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
            'textarea.textarea',
            'textarea',
            'div[contenteditable="true"]',
            'rich-textarea [contenteditable="true"]',
            'rich-textarea div p',
            '.ql-editor',
            '[role="textbox"]',
            '[aria-label*="Prompt"]',
            '[aria-label*="Type something"]',
            '[placeholder*="Type something"]'
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

    function hasAttachedFile() {
        return !!document.querySelector(
            'img[src^="blob:"], img[src^="data:"], img.thumbnail, .image-preview, .uploader-preview, ' +
            'mat-chip, .attachment-card, .file-preview, [aria-label*="Delete image"], [aria-label*="ลบรูปภาพ"], ' +
            '[aria-label*="Remove"], [aria-label*="Delete"], button[mattooltip*="Delete"], button[mattooltip*="Remove"]'
        );
    }

    function isUploading() {
        // Specific progress spinners inside attachment cards or input area
        return !!document.querySelector(
            '.attachment-card mat-progress-spinner, .attachment-card mat-spinner, ' +
            '.image-preview mat-progress-spinner, .image-preview mat-spinner, ' +
            'rich-textarea mat-progress-spinner, rich-textarea mat-spinner, ' +
            '.input-area mat-progress-spinner, .input-area mat-spinner, ' +
            '.attachment-card .loading, .attachment-card .uploading'
        );
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
            let container = inputEl.closest('rich-textarea, .input-area, .chat-input, .text-input-field, form, .input-container, .bottom-container') || inputEl.parentElement;
            for (let depth = 0; depth < 5 && container; depth++) {
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
            'button[data-test-id="send-button"]',
            'button[data-test-id*="send"]',
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

    function executeSubmit(el, hasFile) {
        if (!shouldSubmit) return;

        let pollCount = 0;
        const maxPoll = 120; // 120 * 25ms = 3.0s
        let sent = false;

        function doSend() {
            if (sent) return true;
            const runBtn = findSendButton(el);
            if (runBtn) {
                sent = true;
                runBtn.click();
                setTimeout(() => { pressEnterKey(el); }, 60);
                return true;
            } else if (el) {
                sent = true;
                pressEnterKey(el);
                return true;
            }
            return false;
        }

        function checkAndSend() {
            if (sent) return true;

            const runBtn = findSendButton(el);
            const isBtnEnabled = runBtn && !runBtn.disabled && runBtn.getAttribute('aria-disabled') !== 'true';

            if (hasFile) {
                const fileInDom = hasAttachedFile();
                const uploading = isUploading();

                if (fileInDom && isBtnEnabled && !uploading) {
                    return doSend();
                }
            } else {
                if (isBtnEnabled && pollCount >= 2) {
                    return doSend();
                }
            }
            return false;
        }

        // Try instant send if ready
        if (checkAndSend()) return;

        // High-frequency 25ms polling for instant response
        const pollTimer = setInterval(() => {
            pollCount++;

            if (checkAndSend() || pollCount >= maxPoll) {
                clearInterval(pollTimer);
                if (observer) observer.disconnect();

                if (!sent && pollCount >= maxPoll) {
                    doSend();
                }
            }
        }, 25);

        // Real-time MutationObserver: triggers the exact microsecond upload spinner disappears
        let observer = null;
        try {
            observer = new MutationObserver(() => {
                if (checkAndSend()) {
                    clearInterval(pollTimer);
                    observer.disconnect();
                }
            });
            observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['disabled', 'aria-disabled', 'class', 'src'] });
        } catch(e) {}
    }

    function performInjection() {
        const el = findPromptInput();
        if (!el) return false;

        el.focus();

        // 1. Inject prompt text
        injectText(el, promptText);

        // 2. Attach image file IMMEDIATELY
        const file = (base64Data && base64Data.length > 10) ? base64ToFile(base64Data, uniqueFileName) : null;
        if (file) {
            attachImage(file, el);
        }

        // 3. High-speed reactive submit polling with 0ms MutationObserver
        executeSubmit(el, !!file);

        return true;
    }

    if (!performInjection()) {
        let attempts = 0;
        const retryTimer = setInterval(() => {
            attempts++;
            if (performInjection() || attempts >= 20) {
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

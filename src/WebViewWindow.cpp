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
        if (!btn || btn.offsetParent === null) return false;
        if (btn.disabled || btn.getAttribute('aria-disabled') === 'true') return false;

        const aria = (btn.getAttribute('aria-label') || '').toLowerCase();
        const testId = (btn.getAttribute('data-test-id') || '').toLowerCase();
        const className = (btn.className || '').toLowerCase();
        const text = (btn.innerText || '').trim().toLowerCase();
        const icon = Array.from(btn.querySelectorAll('mat-icon, svg, span, i')).map(e => (e.innerText || e.getAttribute('aria-label') || e.className || '').toLowerCase()).join(' ');

        // Disqualify mic, tools, model selector, attach buttons
        if (aria.includes('mic') || aria.includes('ไมค์') || aria.includes('audio') || aria.includes('voice')) return false;
        if (aria.includes('model') || aria.includes('โมเดล') || aria.includes('flash') || aria.includes('pro')) return false;
        if (aria.includes('add') || aria.includes('attach') || aria.includes('แนบ') || aria.includes('upload') || aria.includes('file') || aria.includes('tools')) return false;
        if (aria.includes('menu') || aria.includes('settings') || aria.includes('help') || aria.includes('account')) return false;

        // Positive match
        if (aria.includes('send') || aria.includes('ส่ง') || aria.includes('submit') || aria.includes('run') || aria.includes('prompt') || aria.includes('พร้อมท์')) return true;
        if (testId.includes('send') || testId.includes('submit')) return true;
        if (className.includes('send') || className.includes('submit')) return true;
        if (text === 'send' || text === 'ส่ง' || text === 'run') return true;
        if (icon.includes('arrow_upward') || icon.includes('send') || icon.includes('north') || icon.includes('arrow-up') || icon.includes('submit')) return true;

        return false;
    }

    function findSendButton(inputEl) {
        // 1. Search inside parent input container hierarchy
        if (inputEl) {
            let cur = inputEl.parentElement;
            for (let depth = 0; depth < 8 && cur && cur !== document.body; depth++) {
                const candidates = Array.from(cur.querySelectorAll('button, div[role="button"]'));
                const found = candidates.find(b => isSendButton(b));
                if (found) return found;
                cur = cur.parentElement;
            }
        }

        // 2. Specific known Gemini send button selectors
        const geminiSelectors = [
            'button.send-button',
            'button[aria-label*="Send message" i]',
            'button[aria-label*="ส่งข้อความ" i]',
            'button[aria-label*="Send prompt" i]',
            'button[aria-label*="ส่งพร้อมท์" i]',
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

        // 3. Fallback: Search all visible buttons near bottom of page
        const allButtons = Array.from(document.querySelectorAll('button, div[role="button"]'));
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

    function getRootInputContainer(el) {
        if (!el) return document.body;
        let cur = el.parentElement;
        for (let i = 0; i < 10 && cur && cur !== document.body; i++) {
            if (cur.querySelector('button') && (
                cur.classList.contains('input-area-container') ||
                cur.classList.contains('bottom-container') ||
                cur.classList.contains('chat-input-container') ||
                cur.tagName === 'FORM' ||
                cur.tagName === 'MAIN'
            )) {
                return cur;
            }
            cur = cur.parentElement;
        }
        return el.closest('.input-area-container, .bottom-container, .chat-input-container, form, main') || el.parentElement || document.body;
    }

    function getAttachmentCards(rootContainer) {
        if (!rootContainer) return [];
        const selectors = [
            '.attachment-card',
            '.attachment-container',
            '.image-preview',
            '.uploader-preview',
            'rich-textarea-attachment-container',
            'img[src^="blob:"]',
            'img[src^="data:image"]',
            '[aria-label*="Remove image" i]',
            '[aria-label*="Delete image" i]',
            '[aria-label*="ลบรูปภาพ" i]',
            '[aria-label*="Remove file" i]',
            '[aria-label*="Delete file" i]',
            'button[mattooltip*="Delete" i]',
            'button[mattooltip*="Remove" i]',
            'button[mattooltip*="ลบ" i]',
            'mat-chip[role="option"]',
            '.file-bubble'
        ];
        const results = [];
        for (const sel of selectors) {
            const list = Array.from(rootContainer.querySelectorAll(sel));
            for (const item of list) {
                if (item.offsetParent !== null && !results.includes(item)) {
                    results.push(item);
                }
            }
        }
        return results;
    }

    function isUploadInProgress(rootContainer) {
        if (!rootContainer) return false;
        const spinnerSelectors = [
            'mat-progress-spinner',
            'mat-spinner',
            '.mat-mdc-progress-spinner',
            '.attachment-card .loading',
            '.attachment-card .uploading',
            '.image-preview .loading',
            '.image-preview .uploading',
            '.uploader-preview .loading',
            '.spinner',
            '[role="progressbar"]'
        ];
        for (const sel of spinnerSelectors) {
            const spinners = Array.from(rootContainer.querySelectorAll(sel));
            if (spinners.some(s => s.offsetParent !== null)) {
                return true;
            }
        }
        return false;
    }

    function performInjection() {
        const el = findPromptInput();
        if (!el) return false;

        el.focus();

        const file = (base64Data && base64Data.length > 10) ? base64ToFile(base64Data, uniqueFileName) : null;
        const rootContainer = getRootInputContainer(el);

        if (file) {
            // Count initial cards strictly before attach
            const initialCardCount = getAttachmentCards(rootContainer).length;
            const attachStartTime = Date.now();
            let attachAttempt = 1;

            // 1. Dispatch Image Attachment FIRST
            attachImage(file, el);

            if (!shouldSubmit) {
                // If not auto-run, simply inject prompt text and let user submit manually
                injectText(el, promptText);
                return true;
            }

            // 2. Strict State Machine for Simultaneous Submission
            // State 0: WAITING_FOR_CARD (Must see new attachment card in DOM)
            // State 1: WAITING_FOR_UPLOAD (Card seen, waiting for progress spinners to finish)
            // State 2: READY_TO_SEND (Card confirmed, no spinners, send button enabled)
            let state = 0; 
            let pollCount = 0;
            const maxPoll = 400; // 10.0 seconds maximum
            let sent = false;

            function doSendNow() {
                if (sent) return true;
                sent = true;

                // Ensure prompt text is firmly in the input field before clicking send
                const currentText = el.innerText || el.value || '';
                if (promptText && !currentText.includes(promptText.trim())) {
                    injectText(el, promptText);
                }

                const runBtn = findSendButton(el);
                if (runBtn) {
                    runBtn.click();
                    setTimeout(() => { pressEnterKey(el); }, 80);
                } else {
                    pressEnterKey(el);
                }
                return true;
            }

            function stepStateMachine() {
                if (sent) return true;

                const elapsed = Date.now() - attachStartTime;
                const cards = getAttachmentCards(rootContainer);
                const hasNewCard = (cards.length > initialCardCount) || (cards.length > 0 && elapsed > 250);
                const uploading = isUploadInProgress(rootContainer);

                // Retry paste if no card seen after 800ms
                if (state === 0 && !hasNewCard && elapsed > 800 * attachAttempt && attachAttempt < 3) {
                    attachAttempt++;
                    attachImage(file, el);
                }

                if (state === 0) {
                    if (hasNewCard) {
                        state = 1; // Card confirmed! Transition to checking upload progress
                        injectText(el, promptText);
                    } else if (elapsed > 3000) {
                        // Safety fallback in case Gemini changed DOM selectors for attachment card
                        state = 1;
                        injectText(el, promptText);
                    } else {
                        // STRICT RULE: DO NOT SEND! We MUST NOT submit if the image hasn't even mounted!
                        return false;
                    }
                }

                if (state === 1) {
                    if (uploading) {
                        // Still uploading bytes, stay in state 1
                        return false;
                    } else {
                        // Upload spinner has disappeared! Make sure prompt text is injected
                        injectText(el, promptText);
                        state = 2; // Ready to check send button
                    }
                }

                if (state === 2) {
                    // Check if send button is enabled
                    const runBtn = findSendButton(el);
                    const isBtnEnabled = runBtn && !runBtn.disabled && runBtn.getAttribute('aria-disabled') !== 'true';

                    if (isBtnEnabled) {
                        return doSendNow();
                    } else if (elapsed > 1200 && !uploading) {
                        // Button might not use standard attributes or Enter key will submit
                        return doSendNow();
                    }
                }

                return false;
            }

            // High-frequency 25ms polling
            const pollTimer = setInterval(() => {
                pollCount++;
                if (stepStateMachine() || pollCount >= maxPoll) {
                    clearInterval(pollTimer);
                    if (observer) observer.disconnect();

                    if (!sent && pollCount >= maxPoll) {
                        // Only submit on timeout if image card was confirmed and not uploading
                        if (state >= 1 && !isUploadInProgress(rootContainer)) {
                            doSendNow();
                        }
                    }
                }
            }, 25);

            // Reactive MutationObserver
            let observer = null;
            try {
                observer = new MutationObserver(() => {
                    if (stepStateMachine()) {
                        clearInterval(pollTimer);
                        observer.disconnect();
                    }
                });
                observer.observe(rootContainer, { childList: true, subtree: true, attributes: true, attributeFilter: ['disabled', 'aria-disabled', 'class', 'src'] });
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

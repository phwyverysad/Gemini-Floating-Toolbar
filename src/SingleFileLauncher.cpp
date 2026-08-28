#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <string>
#include <vector>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "advapi32.lib")

#define IDR_EMBEDDED_ZIP 2001

static std::wstring GetAppTargetDirectory() {
    wchar_t localAppData[MAX_PATH] = { 0 };
    GetEnvironmentVariableW(L"LOCALAPPDATA", localAppData, MAX_PATH);
    std::wstring folder = std::wstring(localAppData) + L"\\GoogleGeminiPortable\\app";
    SHCreateDirectoryExW(nullptr, folder.c_str(), nullptr);
    return folder;
}

static std::wstring GetTempZipPath() {
    wchar_t tempPath[MAX_PATH] = { 0 };
    GetTempPathW(MAX_PATH, tempPath);
    return std::wstring(tempPath) + L"Gemini_Payload.zip";
}

static bool ExtractEmbeddedZip(HINSTANCE hInstance, const std::wstring& zipPath) {
    HRSRC hRes = FindResourceW(hInstance, MAKEINTRESOURCEW(IDR_EMBEDDED_ZIP), MAKEINTRESOURCEW(10)); // 10 is RT_RCDATA
    if (!hRes) return false;

    HGLOBAL hMem = LoadResource(hInstance, hRes);
    if (!hMem) return false;

    DWORD resSize = SizeofResource(hInstance, hRes);
    void* pData = LockResource(hMem);
    if (!pData || resSize == 0) return false;

    HANDLE hFile = CreateFileW(zipPath.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (hFile == INVALID_HANDLE_VALUE) return false;

    DWORD bytesWritten = 0;
    BOOL bSuccess = WriteFile(hFile, pData, resSize, &bytesWritten, nullptr);
    CloseHandle(hFile);

    return (bSuccess && bytesWritten == resSize);
}

static bool UnpackZipToDirectory(const std::wstring& zipPath, const std::wstring& targetDir) {
    std::wstring psCmd = L"-NoProfile -ExecutionPolicy Bypass -Command \"Expand-Archive -Path '" + zipPath + L"' -DestinationPath '" + targetDir + L"' -Force\"";
    
    SHELLEXECUTEINFOW sei = {};
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_NOCLOSEPROCESS;
    sei.lpVerb = L"open";
    sei.lpFile = L"powershell.exe";
    sei.lpParameters = psCmd.c_str();
    sei.nShow = SW_HIDE;

    if (ShellExecuteExW(&sei) && sei.hProcess) {
        WaitForSingleObject(sei.hProcess, 60000);
        CloseHandle(sei.hProcess);
        return true;
    }
    return false;
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, PWSTR pCmdLine, int) {
    std::wstring targetDir = GetAppTargetDirectory();
    std::wstring targetExe = targetDir + L"\\Gemini.exe";
    std::wstring stampFile = targetDir + L"\\.version_stamp";

    // Read current launcher write time
    wchar_t launcherPath[MAX_PATH] = { 0 };
    GetModuleFileNameW(nullptr, launcherPath, MAX_PATH);

    bool needsExtraction = false;
    if (!PathFileExistsW(targetExe.c_str())) {
        needsExtraction = true;
    } else {
        // Compare write time with stamp
        HANDLE hLauncher = CreateFileW(launcherPath, GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
        if (hLauncher != INVALID_HANDLE_VALUE) {
            FILETIME ftLauncher = {};
            GetFileTime(hLauncher, nullptr, nullptr, &ftLauncher);
            CloseHandle(hLauncher);

            HANDLE hStamp = CreateFileW(stampFile.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
            if (hStamp != INVALID_HANDLE_VALUE) {
                FILETIME ftStamp = {};
                DWORD bytesRead = 0;
                ReadFile(hStamp, &ftStamp, sizeof(FILETIME), &bytesRead, nullptr);
                CloseHandle(hStamp);

                if (bytesRead != sizeof(FILETIME) || 
                    ftLauncher.dwLowDateTime != ftStamp.dwLowDateTime || 
                    ftLauncher.dwHighDateTime != ftStamp.dwHighDateTime) {
                    needsExtraction = true;
                }
            } else {
                needsExtraction = true;
            }
        }
    }

    if (needsExtraction) {
        std::wstring tempZip = GetTempZipPath();
        if (ExtractEmbeddedZip(hInstance, tempZip)) {
            UnpackZipToDirectory(tempZip, targetDir);
            DeleteFileW(tempZip.c_str());

            // Write version stamp
            HANDLE hLauncher = CreateFileW(launcherPath, GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
            if (hLauncher != INVALID_HANDLE_VALUE) {
                FILETIME ftLauncher = {};
                GetFileTime(hLauncher, nullptr, nullptr, &ftLauncher);
                CloseHandle(hLauncher);

                HANDLE hStamp = CreateFileW(stampFile.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
                if (hStamp != INVALID_HANDLE_VALUE) {
                    DWORD bytesWritten = 0;
                    WriteFile(hStamp, &ftLauncher, sizeof(FILETIME), &bytesWritten, nullptr);
                    CloseHandle(hStamp);
                }
            }
        }
    }

    if (!PathFileExistsW(targetExe.c_str())) {
        MessageBoxW(nullptr, L"Failed to start Google Gemini Desktop. Please check disk space and permissions.", L"Google Gemini", MB_ICONERROR | MB_OK);
        return 1;
    }

    // Launch Gemini.exe passing all command line arguments
    std::wstring cmdLine = L"\"" + targetExe + L"\"";
    if (pCmdLine && wcslen(pCmdLine) > 0) {
        cmdLine += L" " + std::wstring(pCmdLine);
    }

    STARTUPINFOW si = {};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi = {};

    std::vector<wchar_t> cmdLineBuf(cmdLine.begin(), cmdLine.end());
    cmdLineBuf.push_back(L'\0');

    if (CreateProcessW(
            targetExe.c_str(),
            cmdLineBuf.data(),
            nullptr, nullptr, FALSE,
            0, nullptr,
            targetDir.c_str(),
            &si, &pi)) {
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        return 0;
    }

    return 1;
}

#include "internal_api.h"

#ifdef _WIN32
#include <windows.h>
#include <vector>

std::wstring Utf8ToWide(const std::string& str) {
    if (str.empty()) return std::wstring();
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
    std::wstring wstrTo(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
    return wstrTo;
}

void AppendArgumentWin(std::wstring& cmdLine, const std::wstring& arg) {
    if (!cmdLine.empty()) cmdLine += L" ";

    if (arg.length() >= 2 && arg.front() == L'"' && arg.back() == L'"') {
        cmdLine += arg;
        return;
    }

    if (arg.find(L' ') == std::wstring::npos && arg.find(L'\t') == std::wstring::npos) {
        cmdLine += arg;
        return;
    }

    cmdLine += L'"';
    for (wchar_t c : arg) {
        if (c == L'"') cmdLine += L"\\\"";
        else cmdLine += c;
    }
    cmdLine += L'"';
}

int ReadPipeWin(void* h, char* buf, int sz) {
    DWORD r = 0;
    if (!PeekNamedPipe((HANDLE)h, NULL, 0, NULL, &r, NULL) || r == 0) {
        if (GetLastError() == ERROR_BROKEN_PIPE) return 0;
        return -1;
    }
    if (ReadFile((HANDLE)h, buf, sz, &r, NULL)) return (int)r;
    return (GetLastError() == ERROR_BROKEN_PIPE) ? 0 : -1;
}
#endif

#ifdef _WIN32
#include "../common/internal_api.h"
#include <windows.h>
#include <winbase.h>
#include <userenv.h>
#include <ntsecapi.h>
#include <sddl.h>
#include <profileapi.h>
#include <vector>
#include <string>

#pragma comment(lib, "userenv.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "kernel32.lib")

#define APP_CONTAINER_ERROR_CONTAINER_ALREADY_EXISTS 0x800705AA

/// RAII helper that automatically closes a Windows HANDLE.
///
/// Ensures we do not leak process, thread or pipe handles if an
/// early return or error occurs.
class ScopedHandle {
public:
  HANDLE h;
  ScopedHandle(HANDLE handle = NULL) : h(handle) {}
  ~ScopedHandle() { close(); }

  void close() {
    if (h && h != INVALID_HANDLE_VALUE) {
      CloseHandle(h);
      h = NULL;
    }
  }

  HANDLE detach() {
    HANDLE temp = h;
    h = NULL;
    return temp;
  }

  HANDLE* operator&() { return &h; }
  operator HANDLE() const { return h; }
};

/// Converts a UTF-8 encoded std::string to a UTF-16 std::wstring
/// suitable for Windows wide APIs.
std::wstring Utf8ToWide(const std::string& str) {
  if (str.empty()) return std::wstring();
  int size_needed = MultiByteToWideChar(
    CP_UTF8,
    0,
    str.data(),
    static_cast<int>(str.size()),
    NULL,
    0
  );
  if (size_needed <= 0) return std::wstring();
  std::wstring wstrTo(size_needed, 0);
  MultiByteToWideChar(
    CP_UTF8,
    0,
    str.data(),
    static_cast<int>(str.size()),
    &wstrTo[0],
    size_needed
  );
  return wstrTo;
}

/// Non-blocking read from a Windows pipe connected to stdout/stderr.
///
/// Returns:
/// - > 0: number of bytes read
/// - 0  : end-of-stream (broken pipe)
/// - -1 : no data available or error
int ReadPipeWin(void* h, char* buf, int sz) {
  if (h == NULL || buf == NULL || sz <= 0) return -1;
  HANDLE pipe = static_cast<HANDLE>(h);

  DWORD avail = 0;
  if (!PeekNamedPipe(pipe, NULL, 0, NULL, &avail, NULL)) {
    DWORD lastError = GetLastError();
    if (lastError == ERROR_BROKEN_PIPE) return 0;
    return -1;
  }

  if (avail == 0) return 0;

  DWORD readBytes = 0;
  if (!ReadFile(pipe, buf, static_cast<DWORD>(sz), &readBytes, NULL)) {
    DWORD lastError = GetLastError();
    if (lastError == ERROR_BROKEN_PIPE || lastError == ERROR_NO_DATA) return 0;
    return -1;
  }
  return static_cast<int>(readBytes);
}

/// Creates (or reuses) a Windows AppContainer and derives a restricted token.
///
/// On success, [appContainerSid] and [hToken] are initialized and can be
/// used to launch a sandboxed process with CreateProcessAsUserW.
bool CreateAppContainer(
  const char* id,
  const char* rootPath,
  PSID* appContainerSid,
  ScopedHandle& hToken
) {
  if (!id || !rootPath) return false;

  std::string appNameStr = std::string(id) + "_workspace";
  std::wstring appName = Utf8ToWide(appNameStr);
  std::wstring displayName = L"Workspace Sandbox";

  HRESULT hr = CreateAppContainerProfile(
    appName.c_str(),
    displayName.c_str(),
    displayName.c_str(),
    NULL,
    0,
    appContainerSid
  );

  if (hr != S_OK && hr != APP_CONTAINER_ERROR_CONTAINER_ALREADY_EXISTS) {
    return false;
  }

  ScopedHandle hProcessToken;
  if (!OpenProcessToken(
        GetCurrentProcess(),
        TOKEN_QUERY | TOKEN_DUPLICATE,
        &hProcessToken.h
      )) {
    return false;
  }

  typedef HRESULT(WINAPI* DeriveProc)(HANDLE, PSID, HANDLE*);
  HMODULE hUserEnv = GetModuleHandleW(L"userenv.dll");
  if (!hUserEnv) hUserEnv = LoadLibraryW(L"userenv.dll");

  DeriveProc pDerive = hUserEnv
    ? (DeriveProc)GetProcAddress(
        hUserEnv,
        "DeriveAppContainerTokenFromToken"
      )
    : NULL;

  if (!pDerive) {
    return false;
  }

  hr = pDerive(hProcessToken.h, *appContainerSid, &hToken.h);

  if (hr != S_OK) {
    return false;
  }

  return true;
}

void CleanupAppContainerSid(PSID appContainerSid) {
  if (appContainerSid) {
    FreeSid(appContainerSid);
  }
}

/// Starts a process on Windows, optionally inside an AppContainer sandbox.
///
/// When [sandbox] is true and the AppContainer setup succeeds, the process
/// is launched using CreateProcessAsUserW with a restricted token. Otherwise
/// it falls back to CreateProcessW with inherited token.
ProcessHandle* StartProcessWindows(
  const char* command_line,
  const char* cwd,
  bool sandbox,
  const char* id
) {
  PROCESS_INFORMATION pi = {};
  STARTUPINFOEXW siEx = {};
  SECURITY_ATTRIBUTES saAttr = {};
  saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
  saAttr.bInheritHandle = TRUE;
  saAttr.lpSecurityDescriptor = NULL;

  ScopedHandle hOutRead, hOutWrite;
  ScopedHandle hErrRead, hErrWrite;
  PSID appContainerSid = NULL;
  ScopedHandle hToken;
  bool useSandbox = sandbox;

  std::wstring cmdLineWide = Utf8ToWide(command_line ? command_line : "");
  std::vector<wchar_t> cmdLineBuf(cmdLineWide.begin(), cmdLineWide.end());
  cmdLineBuf.push_back(L'\0');

  std::wstring cwdWide = Utf8ToWide(cwd ? cwd : "");

  if (!CreatePipe(&hOutRead.h, &hOutWrite.h, &saAttr, 0)) return nullptr;
  if (!CreatePipe(&hErrRead.h, &hErrWrite.h, &saAttr, 0)) return nullptr;

  SetHandleInformation(hOutRead.h, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(hErrRead.h, HANDLE_FLAG_INHERIT, 0);

  siEx.StartupInfo.cb = sizeof(STARTUPINFOEXW);
  siEx.StartupInfo.hStdOutput = hOutWrite.h;
  siEx.StartupInfo.hStdError = hErrWrite.h;
  siEx.StartupInfo.dwFlags = STARTF_USESTDHANDLES;

  if (sandbox) {
    if (!CreateAppContainer(id, cwd ? cwd : ".", &appContainerSid, hToken)) {
      useSandbox = false;
      if (appContainerSid) {
        CleanupAppContainerSid(appContainerSid);
        appContainerSid = NULL;
      }
    }
  }

  BOOL createSuccess = FALSE;
  DWORD creationFlags = CREATE_UNICODE_ENVIRONMENT | EXTENDED_STARTUPINFO_PRESENT;

  if (useSandbox && hToken.h) {
    createSuccess = CreateProcessAsUserW(
      hToken.h,
      NULL,
      cmdLineBuf.data(),
      NULL,
      NULL,
      TRUE,
      creationFlags,
      NULL,
      cwdWide.empty() ? NULL : cwdWide.c_str(),
      &siEx.StartupInfo,
      &pi
    );
  } else {
    createSuccess = CreateProcessW(
      NULL,
      cmdLineBuf.data(),
      NULL,
      NULL,
      TRUE,
      creationFlags,
      NULL,
      cwdWide.empty() ? NULL : cwdWide.c_str(),
      &siEx.StartupInfo,
      &pi
    );
  }

  hOutWrite.close();
  hErrWrite.close();

  if (!createSuccess) {
    if (appContainerSid) CleanupAppContainerSid(appContainerSid);
    return nullptr;
  }

  ProcessHandle* handle = new ProcessHandle();
  handle->hProcess = pi.hProcess;
  CloseHandle(pi.hThread);

  handle->hOutRead = hOutRead.detach();
  handle->hErrRead = hErrRead.detach();

  handle->isRunning = true;
  handle->exitCode = -1;

  if (appContainerSid) FreeSid(appContainerSid);

  return handle;
}
#endif

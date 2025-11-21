#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#ifndef INTERNAL_API_H
#define INTERNAL_API_H

#include "../../include/workspace_core.h"
#include <string>

/// Internal representation of a native process handle.
///
/// Mirrors the opaque [ProcessHandle] declared in `workspace_core.h`,
/// but exposes the platform-specific fields needed by the implementation.
struct ProcessHandle {
#ifdef _WIN32
  void* hProcess;
  void* hThread;
  void* hOutRead;
  void* hErrRead;
#else
  int pid;
  int fdOut;
  int fdErr;
#endif
  int exitCode;
  bool isRunning;
};

/// Platform-specific entry point for starting a process on Windows.
///
/// May run the process inside a Windows AppContainer when [sandbox] is true.
#ifdef _WIN32
ProcessHandle* StartProcessWindows(
  const char* command_line,
  const char* cwd,
  bool sandbox,
  const char* id
);

/// Non-blocking read helper for Windows named pipes.
int ReadPipeWin(void* handle, char* buffer, int size);

/// UTF-8 to UTF-16 helper used for building Windows command lines.
std::wstring Utf8ToWide(const std::string& str);
#else

/// Platform-specific entry point for starting a process on Linux/Unix.
///
/// May wrap the command in a bubblewrap sandbox when [sandbox] is true.
ProcessHandle* StartProcessLinux(
  const char* command_line,
  const char* cwd,
  bool sandbox,
  const char* id
);

/// Non-blocking read helper for Unix file descriptors (stdout/stderr).
int ReadPipeUnix(int fd, char* buffer, int size);
#endif

#endif // INTERNAL_API_H

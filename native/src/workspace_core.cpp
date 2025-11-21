#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "../include/workspace_core.h"
#include "common/internal_api.h"

#ifdef _WIN32
  #include <windows.h>
#else
  #include <unistd.h>
  #include <sys/wait.h>
  #include <signal.h>
  #include <errno.h>
#endif

extern "C" {

WORKSPACE_EXPORT ProcessHandle* workspace_start(WorkspaceOptionsC* options) {
  if (!options || !options->command_line) {
    return nullptr;
  }

#ifdef _WIN32
  return StartProcessWindows(
    options->command_line,
    options->cwd,
    options->sandbox,
    options->id
  );
#else
  return StartProcessLinux(
    options->command_line,
    options->cwd,
    options->sandbox,
    options->id
  );
#endif
}

WORKSPACE_EXPORT int workspace_read_stdout(
  ProcessHandle* handle,
  char* buffer,
  int size
) {
#ifdef _WIN32
  return handle && handle->hOutRead
    ? ReadPipeWin(handle->hOutRead, buffer, size)
    : 0;
#else
  if (!handle) return 0;
  ssize_t bytes = read(handle->fdOut, buffer, static_cast<size_t>(size));
  if (bytes > 0) return static_cast<int>(bytes);
  if (bytes == 0) return 0;
  if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) return -1;
  return 0;
#endif
}

WORKSPACE_EXPORT int workspace_read_stderr(
  ProcessHandle* handle,
  char* buffer,
  int size
) {
#ifdef _WIN32
  return handle && handle->hErrRead
    ? ReadPipeWin(handle->hErrRead, buffer, size)
    : 0;
#else
  if (!handle) return 0;
  ssize_t bytes = read(handle->fdErr, buffer, static_cast<size_t>(size));
  if (bytes > 0) return static_cast<int>(bytes);
  if (bytes == 0) return 0;
  if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) return -1;
  return 0;
#endif
}

WORKSPACE_EXPORT int workspace_is_running(
  ProcessHandle* handle,
  int* exit_code
) {
  if (!handle) {
    if (exit_code) *exit_code = -1;
    return 0;
  }

#ifdef _WIN32
  if (!handle->isRunning) {
    if (exit_code) *exit_code = handle->exitCode;
    return 0;
  }

  DWORD code = 0;
  if (GetExitCodeProcess(static_cast<HANDLE>(handle->hProcess), &code)) {
    if (code == STILL_ACTIVE) {
      if (exit_code) *exit_code = handle->exitCode;
      return 1;
    }
    handle->isRunning = false;
    handle->exitCode = static_cast<int>(code);
    if (exit_code) *exit_code = handle->exitCode;
    return 0;
  }

  handle->isRunning = false;
  handle->exitCode = -1;
  if (exit_code) *exit_code = handle->exitCode;
  return 0;
#else
  if (!handle->isRunning) {
    if (exit_code) *exit_code = handle->exitCode;
    return 0;
  }

  int status = 0;
  pid_t result = waitpid(handle->pid, &status, WNOHANG);

  if (result == 0) {
    if (exit_code) *exit_code = handle->exitCode;
    return 1;
  }

  handle->isRunning = false;

  if (result == handle->pid) {
    if (WIFEXITED(status)) {
      handle->exitCode = WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
      handle->exitCode = -128 + WTERMSIG(status);
    } else {
      handle->exitCode = -1;
    }
  } else {
    if (handle->exitCode == -1) {
      handle->exitCode = 0;
    }
  }

  if (exit_code) *exit_code = handle->exitCode;
  return 0;
#endif
}

WORKSPACE_EXPORT void workspace_kill(ProcessHandle* handle) {
  if (!handle) return;

#ifdef _WIN32
  if (handle->isRunning && handle->hProcess) {
    TerminateProcess(static_cast<HANDLE>(handle->hProcess), 1);
  }
#else
  if (handle->isRunning) {
    kill(handle->pid, SIGTERM);
  }
#endif
}

WORKSPACE_EXPORT void workspace_free_handle(ProcessHandle* handle) {
  if (!handle) return;

#ifdef _WIN32
  if (handle->hProcess) CloseHandle(static_cast<HANDLE>(handle->hProcess));
  if (handle->hThread)  CloseHandle(static_cast<HANDLE>(handle->hThread));
  if (handle->hOutRead) CloseHandle(static_cast<HANDLE>(handle->hOutRead));
  if (handle->hErrRead) CloseHandle(static_cast<HANDLE>(handle->hErrRead));
#else
  if (handle->fdOut >= 0) close(handle->fdOut);
  if (handle->fdErr >= 0) close(handle->fdErr);
#endif

  delete handle;
}

} // extern "C"

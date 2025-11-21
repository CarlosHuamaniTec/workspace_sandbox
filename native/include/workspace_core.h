#ifndef WORKSPACE_CORE_H
#define WORKSPACE_CORE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef _WIN32
  #define WORKSPACE_EXPORT __declspec(dllexport)
#else
  #define WORKSPACE_EXPORT __attribute__((visibility("default")))
#endif

extern "C" {

  /// Options passed from Dart to the native workspace core.
  ///
  /// All strings are UTF-8 encoded and owned by the caller.
  typedef struct {
    /// Full command line to execute, as a single UTF-8 string.
    const char* command_line;

    /// Optional working directory for the process (UTF-8 path).
    /// May be null to use the current process working directory.
    const char* cwd;

    /// Whether the process should run inside a sandbox, if supported
    /// on the current platform (AppContainer on Windows, bubblewrap on Linux).
    bool sandbox;

    /// Logical workspace identifier, used for sandbox naming or logging.
    const char* id;
  } WorkspaceOptionsC;

  /// Opaque handle to a native process managed by the workspace core.
  ///
  /// The concrete layout is defined internally and must not be
  /// accessed directly by callers.
  typedef struct ProcessHandle ProcessHandle;

  /// Starts a new process using the given options.
  ///
  /// Returns a non-null [ProcessHandle] on success, or null if the
  /// process could not be started.
  WORKSPACE_EXPORT ProcessHandle* workspace_start(WorkspaceOptionsC* options);

  /// Reads available bytes from the process stdout stream into [buffer].
  ///
  /// Returns:
  /// - > 0: number of bytes read
  /// - 0  : end-of-stream (pipe closed)
  /// - -1 : no data available yet (try again later)
  WORKSPACE_EXPORT int workspace_read_stdout(
    ProcessHandle* handle,
    char* buffer,
    int size
  );

  /// Reads available bytes from the process stderr stream into [buffer].
  ///
  /// Same return semantics as [workspace_read_stdout].
  WORKSPACE_EXPORT int workspace_read_stderr(
    ProcessHandle* handle,
    char* buffer,
    int size
  );

  /// Checks whether the process is still running.
  ///
  /// If the process has already terminated, [exit_code] (when non-null)
  /// is set to the final exit code. Returns 1 when the process is still
  /// alive, 0 otherwise.
  WORKSPACE_EXPORT int workspace_is_running(
    ProcessHandle* handle,
    int* exit_code
  );

  /// Requests termination of the process associated with [handle].
  ///
  /// On POSIX this typically sends SIGTERM; on Windows it calls
  /// TerminateProcess on the underlying handle.
  WORKSPACE_EXPORT void workspace_kill(ProcessHandle* handle);

  /// Releases all native resources associated with [handle].
  ///
  /// After this call, [handle] must no longer be used.
  WORKSPACE_EXPORT void workspace_free_handle(ProcessHandle* handle);
}

#endif // WORKSPACE_CORE_H

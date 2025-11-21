import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart' as ffi_helpers;

import 'native_binding.dart';
import 'native_loader.dart';

/// Thin wrapper around the native workspace_core dynamic library.
///
/// This class is responsible for resolving native symbols once and
/// exposing them as Dart functions with the correct FFI signatures.
class FfiBridge {
  static ffi.DynamicLibrary get _library => NativeLoader.load();

  static StartDart? _startFunc;
  static ReadDart? _readStdoutFunc;
  static ReadDart? _readStderrFunc;
  static IsRunningDart? _isRunningFunc;
  static KillDart? _killFunc;
  static FreeDart? _freeFunc;

  static void _initFuncs() {
    if (_startFunc != null) return;
    final lib = _library;
    _startFunc = lib.lookupFunction<StartC, StartDart>('workspace_start');
    _readStdoutFunc =
        lib.lookupFunction<ReadC, ReadDart>('workspace_read_stdout');
    _readStderrFunc =
        lib.lookupFunction<ReadC, ReadDart>('workspace_read_stderr');
    _isRunningFunc =
        lib.lookupFunction<IsRunningC, IsRunningDart>('workspace_is_running');
    _killFunc = lib.lookupFunction<KillC, KillDart>('workspace_kill');
    _freeFunc = lib.lookupFunction<FreeC, FreeDart>('workspace_free_handle');
  }

  /// Starts a new native process and returns its [ProcessHandle].
  static ffi.Pointer<ProcessHandle> start(
    String commandLine,
    String workingDirectory,
    bool sandbox,
    String id,
    ffi_helpers.Arena arena,
  ) {
    _initFuncs();

    final options = arena<WorkspaceOptionsC>();
    options.ref.command_line = commandLine.toNativeUtf8(allocator: arena);
    options.ref.cwd = workingDirectory.toNativeUtf8(allocator: arena);
    options.ref.sandbox = sandbox;
    options.ref.id = id.toNativeUtf8(allocator: arena);

    final result = _startFunc!(options);
    if (result.address == 0) {
      throw Exception('Native start failed for: $commandLine');
    }
    return result;
  }

  /// Reads available bytes from the native stdout buffer into [buffer].
  static int readStdout(
    ffi.Pointer<ProcessHandle> handle,
    ffi.Pointer<ffi.Uint8> buffer,
    int size,
  ) =>
      _readStdoutFunc!(handle, buffer, size);

  /// Reads available bytes from the native stderr buffer into [buffer].
  static int readStderr(
    ffi.Pointer<ProcessHandle> handle,
    ffi.Pointer<ffi.Uint8> buffer,
    int size,
  ) =>
      _readStderrFunc!(handle, buffer, size);

  /// Returns `true` if the native process is still running.
  ///
  /// When the process has exited, [exitCodeOut] is set to the final exit code.
  static bool isRunning(
    ffi.Pointer<ProcessHandle> handle,
    ffi.Pointer<ffi.Int32> exitCodeOut,
  ) =>
      _isRunningFunc!(handle, exitCodeOut) != 0;

  /// Requests termination of the native process behind [handle].
  static void kill(ffi.Pointer<ProcessHandle> handle) => _killFunc!(handle);

  /// Releases the native [ProcessHandle] and any associated resources.
  static void free(ffi.Pointer<ProcessHandle> handle) => _freeFunc!(handle);
}

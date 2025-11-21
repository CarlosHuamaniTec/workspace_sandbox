import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart' as ffi_helpers;

import 'models/command_result.dart';
import 'models/workspace_options.dart';
import 'models/workspace_process.dart';
import 'native/ffi_bridge.dart';
import 'native/native_binding.dart';
import 'util/shell_parser.dart';

/// Internal implementation that bridges [Workspace] to the native core.
///
/// This class is not exposed publicly; it is responsible for translating
/// high‑level options into FFI calls and managing native resources.
class WorkspaceImpl {
  final String rootPath;
  final String id;
  final WorkspaceOptions _defaultOptions;

  WorkspaceImpl(
    this.rootPath,
    this.id, {
    WorkspaceOptions? options,
  }) : _defaultOptions = options ?? const WorkspaceOptions();

  /// Runs [commandLine] to completion and returns an aggregated [CommandResult].
  Future<CommandResult> run(
    String commandLine, {
    WorkspaceOptions? options,
  }) async {
    WorkspaceProcess process;
    try {
      process = await start(commandLine, options: options);
    } catch (e) {
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Failed to start process: $e',
        duration: Duration.zero,
      );
    }

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();

    final outSub = process.stdout.listen(stdoutBuf.write);
    final errSub = process.stderr.listen(stderrBuf.write);

    final code = await process.exitCode;

    await outSub.cancel();
    await errSub.cancel();

    return CommandResult(
      exitCode: code,
      stdout: stdoutBuf.toString(),
      stderr: stderrBuf.toString(),
      duration: Duration.zero,
      isCancelled: (process as _RealProcess)._isCancelled,
    );
  }

  /// Starts a new process using the native core and returns a [WorkspaceProcess].
  Future<WorkspaceProcess> start(
    String commandLine, {
    WorkspaceOptions? options,
  }) async {
    final opts = options ?? _defaultOptions;
    final workingDirectory = opts.workingDirectoryOverride ?? rootPath;
    final arena = ffi_helpers.Arena();

    final finalCommandLine = ShellParser.prepareCommand(commandLine);

    try {
      final handle = FfiBridge.start(
        finalCommandLine,
        workingDirectory,
        opts.sandbox,
        id,
        arena,
      );

      if (handle.address == 0) {
        throw Exception(
          'Native failure: could not start process "$finalCommandLine".',
        );
      }

      return _RealProcess(handle, arena, opts.timeout);
    } catch (e) {
      arena.releaseAll();
      rethrow;
    }
  }
}

/// Concrete [WorkspaceProcess] backed by a native process handle.
///
/// Periodically polls native stdout/stderr and completion state using
/// [FfiBridge], exposing results as Dart streams and futures.
class _RealProcess implements WorkspaceProcess {
  final ffi.Pointer<ProcessHandle> _handle;
  final ffi_helpers.Arena _arena;

  final _stdoutCtrl = StreamController<String>();
  final _stderrCtrl = StreamController<String>();
  final _exitCodeCompleter = Completer<int>();

  bool _isCancelled = false;
  Timer? _pollingTimer;
  Timer? _timeoutTimer;

  _RealProcess(
    this._handle,
    this._arena,
    Duration? timeout,
  ) {
    _startPolling();

    if (timeout != null) {
      _timeoutTimer = Timer(timeout, () {
        if (_exitCodeCompleter.isCompleted) return;
        _isCancelled = true;
        kill();
        if (!_stderrCtrl.isClosed) {
          _stderrCtrl.add('\nError: process timeout exceeded.\n');
        }
      });
    }
  }

  @override
  Stream<String> get stdout => _stdoutCtrl.stream;

  @override
  Stream<String> get stderr => _stderrCtrl.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  void kill() => FfiBridge.kill(_handle);

  void _startPolling() {
    final buffer = ffi_helpers.calloc<ffi.Uint8>(4096);
    final exitCodePtr = ffi_helpers.calloc<ffi.Int32>();

    void poll() {
      if (_exitCodeCompleter.isCompleted) {
        ffi_helpers.calloc.free(buffer);
        ffi_helpers.calloc.free(exitCodePtr);
        return;
      }

      bool gotData = false;

      void readStream(
        int Function(
          ffi.Pointer<ProcessHandle>,
          ffi.Pointer<ffi.Uint8>,
          int,
        ) readFunc,
        StreamController<String> ctrl,
      ) {
        if (ctrl.isClosed) return;

        while (true) {
          final bytes = readFunc(_handle, buffer, 4096);
          if (bytes > 0) {
            gotData = true;
            ctrl.add(
              utf8.decode(
                buffer.asTypedList(bytes),
                allowMalformed: true,
              ),
            );
          } else {
            break;
          }
        }
      }

      readStream(FfiBridge.readStdout, _stdoutCtrl);
      readStream(FfiBridge.readStderr, _stderrCtrl);

      final isAlive = FfiBridge.isRunning(_handle, exitCodePtr);

      if (!isAlive) {
        // Flush remaining data one last time.
        readStream(FfiBridge.readStdout, _stdoutCtrl);
        readStream(FfiBridge.readStderr, _stderrCtrl);

        _finalize(exitCodePtr.value);

        ffi_helpers.calloc.free(buffer);
        ffi_helpers.calloc.free(exitCodePtr);
      } else {
        _pollingTimer = Timer(
          gotData ? Duration.zero : const Duration(milliseconds: 5),
          poll,
        );
      }
    }

    poll();
  }

  void _finalize(int code) {
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();

    FfiBridge.free(_handle);
    _arena.releaseAll();

    if (!_stdoutCtrl.isClosed) _stdoutCtrl.close();
    if (!_stderrCtrl.isClosed) _stderrCtrl.close();

    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
  }
}

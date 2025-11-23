import 'dart:async';
import 'package:workspace_sandbox/src/models/workspace_process.dart';
import 'package:workspace_sandbox/src/native/native_process_impl.dart';

import 'models/command_result.dart';
import 'models/workspace_options.dart';
import 'models/workspace_event.dart';
import 'core/launcher_service.dart';
import 'fs/file_system_service.dart';

/// Internal implementation of the workspace logic.
///
/// Coordinates between the launcher service (for process execution) and
/// the file system service (for file operations), and manages the central
/// event bus for reactive logging.
///
/// This class is not part of the public API.
class WorkspaceImpl {
  /// Unique identifier for this workspace instance.
  final String id;

  /// Default options applied to all commands unless overridden.
  final WorkspaceOptions defaultOptions;

  late final LauncherService _launcher;

  /// File system service for managing workspace files.
  final FileSystemService fs;

  /// Central event bus for broadcasting workspace events.
  final _eventController = StreamController<WorkspaceEvent>.broadcast();

  /// Stream of all events happening in this workspace.
  Stream<WorkspaceEvent> get onEvent => _eventController.stream;

  /// Creates a new workspace implementation.
  ///
  /// Parameters:
  /// - [rootPath]: Absolute path to the workspace root
  /// - [id]: Unique identifier for logging
  /// - [options]: Default configuration for all operations
  WorkspaceImpl(String rootPath, this.id, {WorkspaceOptions? options})
      : defaultOptions = options ?? const WorkspaceOptions(),
        fs = FileSystemService(rootPath) {
    _launcher = LauncherService(rootPath, id);
  }

  /// Absolute path to the workspace root directory.
  String get rootPath => fs.rootPath;

  /// Disposes resources and closes the event stream.
  Future<void> dispose() async {
    await _eventController.close();
  }

  /// Executes a shell command and waits for completion.
  ///
  /// Internally uses [start] to connect to the event bus, then collects
  /// the full output.
  Future<CommandResult> run(String shellCommand,
      {WorkspaceOptions? options}) async {
    final opts = _mergeOptions(options);
    final process = await start(shellCommand, options: opts);
    return _collectResult(process);
  }

  /// Executes a binary directly and waits for completion.
  Future<CommandResult> exec(String executable, List<String> args,
      {WorkspaceOptions? options}) async {
    final opts = _mergeOptions(options);
    final process = await spawn(executable, args, options: opts);
    return _collectResult(process);
  }

  /// Spawns a shell command as a background process.
  ///
  /// Attaches the process to the event bus for real-time logging.
  Future<WorkspaceProcess> start(String shellCommand,
      {WorkspaceOptions? options}) async {
    final opts = _mergeOptions(options);
    final process = await _launcher.spawnShell(shellCommand, opts);

    _attachToEventBus(process, shellCommand);

    return process;
  }

  /// Spawns a binary directly as a background process.
  Future<WorkspaceProcess> spawn(String executable, List<String> args,
      {WorkspaceOptions? options}) async {
    final opts = _mergeOptions(options);
    final process = await _launcher.spawnExec(executable, args, opts);

    _attachToEventBus(process, '$executable ${args.join(" ")}');

    return process;
  }

  /// Attaches a process to the central event bus.
  ///
  /// Emits lifecycle and output events as the process runs.
  void _attachToEventBus(WorkspaceProcess process, String commandLabel) {
    int pid = 0;
    if (process is NativeProcessImpl) {
      try {
        pid = (process as dynamic).pid;
      } catch (_) {
        pid = process.hashCode;
      }
    } else {
      pid = process.hashCode;
    }

    // Emit started event
    _eventController.add(ProcessLifecycleEvent(
      workspaceId: id,
      pid: pid,
      command: commandLabel,
      state: ProcessState.started,
    ));

    // Forward stdout events
    process.stdout.listen((data) {
      _eventController.add(ProcessOutputEvent(
        workspaceId: id,
        pid: pid,
        command: commandLabel,
        content: data,
        isError: false,
      ));
    });

    // Forward stderr events
    process.stderr.listen((data) {
      _eventController.add(ProcessOutputEvent(
        workspaceId: id,
        pid: pid,
        command: commandLabel,
        content: data,
        isError: true,
      ));
    });

    // Emit stopped event when process exits
    process.exitCode.then((code) {
      _eventController.add(ProcessLifecycleEvent(
        workspaceId: id,
        pid: pid,
        command: commandLabel,
        state: ProcessState.stopped,
        exitCode: code,
      ));
    });
  }

  /// Merges default options with per-call overrides.
  WorkspaceOptions _mergeOptions(WorkspaceOptions? override) {
    if (override == null) return defaultOptions;

    return WorkspaceOptions(
      timeout: override.timeout ?? defaultOptions.timeout,
      env: {...defaultOptions.env, ...override.env},
      includeParentEnv: override.includeParentEnv,
      cancellationToken:
          override.cancellationToken ?? defaultOptions.cancellationToken,
      workingDirectoryOverride: override.workingDirectoryOverride ??
          defaultOptions.workingDirectoryOverride,
      sandbox: defaultOptions.sandbox || override.sandbox,
      allowNetwork: override.allowNetwork,
    );
  }

  /// Collects the full output from a process into a [CommandResult].
  Future<CommandResult> _collectResult(WorkspaceProcess process) async {
    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();
    final stopwatch = Stopwatch()..start();

    await Future.wait([
      process.stdout.forEach(stdoutBuf.write),
      process.stderr.forEach(stderrBuf.write)
    ]);

    final code = await process.exitCode;
    stopwatch.stop();

    bool isCancelled = false;
    if (process is NativeProcessImpl) {
      isCancelled = process.isCancelled;
    }

    return CommandResult(
      exitCode: code,
      stdout: stdoutBuf.toString(),
      stderr: stderrBuf.toString(),
      duration: stopwatch.elapsed,
      isCancelled: isCancelled,
    );
  }
}

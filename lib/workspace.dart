import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;

import 'src/models/command_result.dart';
import 'src/models/workspace_options.dart';
import 'src/models/workspace_process.dart';
import 'src/workspace_impl.dart';

export 'src/models/command_result.dart';
export 'src/models/workspace_options.dart';
export 'src/models/workspace_process.dart';

/// High‑level entry point for running commands inside an isolated workspace.
///
/// A [Workspace] represents a root directory where files can be created,
/// modified and executed without leaking outside that root. It can either
/// point to a real host directory ([Workspace.host]) or to a temporary,
/// ephemeral sandbox ([Workspace.secure]).
class Workspace {
  /// Stable identifier for this workspace instance.
  final String id;

  /// Absolute path to the workspace root on the host file system.
  final String rootPath;

  final bool _isSandboxed;
  final bool _isEphemeral;
  final WorkspaceOptions _options;

  late final WorkspaceImpl _impl;

  /// Creates a temporary, sandboxed workspace in the system temp directory.
  ///
  /// The workspace is backed by a new directory under [Directory.systemTemp]
  /// and is automatically deleted when [dispose] is called.
  factory Workspace.secure({
    String? id,
    WorkspaceOptions? options,
  }) {
    final finalId = id ?? _generateId();
    final tempDir = Directory.systemTemp.createTempSync('sandbox_${finalId}_');

    final mergedOptions = _mergeOptions(options, true);

    return Workspace._(
      id: finalId,
      rootPath: tempDir.path,
      isSandboxed: true,
      isEphemeral: true,
      options: mergedOptions,
    );
  }

  /// Creates a workspace rooted at an existing (or newly created) host path.
  ///
  /// If the directory at [path] does not exist, it will be created
  /// recursively. The workspace is not ephemeral and will not be deleted
  /// by [dispose].
  factory Workspace.host(
    String path, {
    String? id,
    WorkspaceOptions? options,
  }) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final mergedOptions = _mergeOptions(options, false);

    return Workspace._(
      id: id ?? _generateId(),
      rootPath: dir.path,
      isSandboxed: false,
      isEphemeral: false,
      options: mergedOptions,
    );
  }

  Workspace._({
    required this.id,
    required this.rootPath,
    required bool isSandboxed,
    required bool isEphemeral,
    required WorkspaceOptions options,
  })  : _isSandboxed = isSandboxed,
        _isEphemeral = isEphemeral,
        _options = options {
    _impl = WorkspaceImpl(rootPath, id, options: _options);
  }

  static String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return List.generate(
      8,
      (index) => chars[rnd.nextInt(chars.length)],
    ).join();
  }

  /// Runs a command to completion and returns the aggregated result.
  ///
  /// This is a convenience wrapper around [start] that buffers all stdout
  /// and stderr output in memory and waits for the exit code.
  ///
  /// Command normalization and shell wrapping are handled internally by
  /// the implementation layer.
  Future<CommandResult> run(
    String commandLine, {
    WorkspaceOptions? options,
  }) {
    final finalOptions = _mergeOptions(options, _isSandboxed);
    return _impl.run(commandLine, options: finalOptions);
  }

  /// Starts a process and returns a [WorkspaceProcess] for streaming output.
  ///
  /// Use this for long‑running commands (servers, dev tools, `ping`, etc.)
  /// when you want to consume stdout/stderr incrementally and control
  /// process lifetime with [WorkspaceProcess.kill].
  ///
  /// Command normalization and shell wrapping are handled internally by
  /// the implementation layer.
  Future<WorkspaceProcess> start(
    String commandLine, {
    WorkspaceOptions? options,
  }) {
    final finalOptions = _mergeOptions(options, _isSandboxed);
    return _impl.start(commandLine, options: finalOptions);
  }

  static WorkspaceOptions _mergeOptions(
    WorkspaceOptions? userOpts,
    bool forceSandbox,
  ) {
    var opts = userOpts ?? const WorkspaceOptions();
    if (forceSandbox != opts.sandbox) {
      return WorkspaceOptions(
        timeout: opts.timeout,
        env: opts.env,
        includeParentEnv: opts.includeParentEnv,
        cancellationToken: opts.cancellationToken,
        workingDirectoryOverride: opts.workingDirectoryOverride,
        sandbox: forceSandbox,
      );
    }
    return opts;
  }

  String _resolve(String relativePath) {
    if (relativePath.contains('..')) {
      throw Exception(
        "Security: access to parent paths ('..') is not allowed.",
      );
    }
    return p.join(rootPath, relativePath);
  }

  /// Writes [content] to a file located at [relativePath] inside the workspace.
  ///
  /// Parent directories are created automatically if they do not exist.
  Future<File> writeFile(String relativePath, String content) async {
    final file = File(_resolve(relativePath));
    await file.parent.create(recursive: true);
    return file.writeAsString(content);
  }

  /// Reads the contents of a file at [relativePath] inside the workspace.
  ///
  /// Throws if the file does not exist.
  Future<String> readFile(String relativePath) async {
    final file = File(_resolve(relativePath));
    if (!await file.exists()) {
      throw Exception('File not found in workspace: $relativePath');
    }
    return file.readAsString();
  }

  /// Returns `true` if a file or directory exists at [relativePath].
  Future<bool> exists(String relativePath) async {
    final path = _resolve(relativePath);
    return await File(path).exists() || await Directory(path).exists();
  }

  /// Creates a directory (and parents) at [relativePath] inside the workspace.
  Future<Directory> createDir(String relativePath) async {
    return Directory(_resolve(relativePath)).create(recursive: true);
  }

  /// Deletes the file or directory at [relativePath] inside the workspace.
  ///
  /// Directories are deleted recursively when present.
  Future<void> delete(String relativePath) async {
    final path = _resolve(relativePath);
    if (await Directory(path).exists()) {
      await Directory(path).delete(recursive: true);
    } else if (await File(path).exists()) {
      await File(path).delete();
    }
  }

  /// Disposes this workspace and frees any ephemeral resources.
  ///
  /// For secure workspaces created with [Workspace.secure], this will
  /// attempt to delete the temporary root directory from disk.
  Future<void> dispose() async {
    if (_isEphemeral) {
      try {
        final dir = Directory(rootPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        // Best effort cleanup only.
        // ignore: avoid_print
        print(
          'Warning: failed to delete temporary workspace ($id): $e',
        );
      }
    }
  }
}

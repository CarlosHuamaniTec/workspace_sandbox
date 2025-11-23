/// A robust, sandboxed workspace manager for executing shell commands securely.
///
/// This library provides cross-platform process isolation using native
/// sandboxing mechanisms (Bubblewrap on Linux, Job Objects on Windows,
/// Seatbelt on macOS) to execute commands in controlled environments.
///
/// ## Features
///
/// - **Ephemeral workspaces**: Temporary sandboxed directories that auto-clean
/// - **Persistent workspaces**: Work on existing project directories
/// - **Network isolation**: Block network access per workspace
/// - **Real-time events**: Stream stdout/stderr and lifecycle events
/// - **File system helpers**: Tree visualization, grep, glob search
///
/// ## Example
///
/// ```
/// import 'package:workspace_sandbox/workspace_sandbox.dart';
///
/// void main() async {
///   final ws = Workspace.ephemeral();
///
///   await ws.writeFile('script.sh', '#!/bin/sh\necho "Hello"');
///   final result = await ws.run('sh script.sh');
///
///   print(result.stdout); // "Hello"
///   await ws.dispose();
/// }
/// ```
library workspace_sandbox;

import 'dart:io';
import 'dart:math';

import 'src/workspace_impl.dart';
import 'src/models/command_result.dart';
import 'src/models/workspace_options.dart';
import 'src/models/workspace_process.dart';
import 'src/models/workspace_event.dart';

export 'src/models/command_result.dart';
export 'src/models/workspace_options.dart';
export 'src/models/workspace_process.dart';
export 'src/models/workspace_event.dart';

/// Represents a secure, isolated workspace for executing commands.
///
/// A workspace provides an isolated environment with sandboxing capabilities
/// for running shell commands, managing files, and observing process output.
///
/// Use [Workspace.ephemeral] for temporary workspaces that auto-clean, or
/// [Workspace.at] to work on existing directories.
abstract class Workspace {
  /// The absolute path to the workspace root directory.
  String get rootPath;

  /// A unified stream of all events happening in this workspace.
  ///
  /// Emits:
  /// - [ProcessLifecycleEvent]: Process start/stop events
  /// - [ProcessOutputEvent]: Real-time stdout/stderr chunks
  ///
  /// This stream is broadcast and can have multiple listeners.
  Stream<WorkspaceEvent> get onEvent;

  /// Creates a temporary workspace in the system temp directory.
  ///
  /// The workspace is automatically sandboxed and will be deleted when
  /// [dispose] is called.
  ///
  /// Example:
  /// ```
  /// final ws = Workspace.ephemeral();
  /// print(ws.rootPath); // /tmp/ws_sb_a1b2c3d4/
  /// await ws.dispose(); // Directory is deleted
  /// ```
  ///
  /// Parameters:
  /// - [id]: Optional unique identifier for logging/debugging
  /// - [options]: Optional configuration (timeout, env vars, network access)
  factory Workspace.ephemeral({String? id, WorkspaceOptions? options}) {
    final wsId = id ?? _generateId();
    final tempDir = Directory.systemTemp.createTempSync('ws_sb_$wsId');
    final secureOpts =
        (options ?? const WorkspaceOptions()).copyWith(sandbox: true);
    return _WorkspaceDelegate(tempDir, wsId,
        options: secureOpts, isTemporary: true);
  }

  /// Creates a workspace at an existing directory path.
  ///
  /// The workspace is persistent and will NOT be deleted on [dispose].
  /// If the directory doesn't exist, it will be created.
  ///
  /// Example:
  /// ```
  /// final ws = Workspace.at('/path/to/project');
  /// await ws.run('git status');
  /// await ws.dispose(); // Files are preserved
  /// ```
  ///
  /// Parameters:
  /// - [path]: Absolute path to the workspace directory
  /// - [id]: Optional unique identifier
  /// - [options]: Optional configuration
  factory Workspace.at(String path, {String? id, WorkspaceOptions? options}) {
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _WorkspaceDelegate(dir, id ?? _generateId(),
        options: options, isTemporary: false);
  }

  @Deprecated('Use Workspace.ephemeral()')
  factory Workspace.secure({String? id, WorkspaceOptions? options}) =
      Workspace.ephemeral;

  @Deprecated('Use Workspace.at()')
  factory Workspace.host(String path, {String? id, WorkspaceOptions? options}) =
      Workspace.at;

  // --- EXECUTION ---

  /// Executes a shell command and waits for completion.
  ///
  /// The command is executed through the system shell (/bin/sh on Unix,
  /// cmd.exe on Windows), allowing shell features like pipes and redirections.
  ///
  /// Example:
  /// ```
  /// final result = await ws.run('ls -la | grep dart');
  /// print(result.stdout);
  /// ```
  ///
  /// Returns a [CommandResult] with exit code, stdout, stderr, and duration.
  Future<CommandResult> run(String shellCommand, {WorkspaceOptions? options});

  /// Executes a binary directly with explicit arguments.
  ///
  /// Unlike [run], this bypasses the shell for better security and avoids
  /// shell injection vulnerabilities.
  ///
  /// Example:
  /// ```
  /// final result = await ws.exec('git', ['commit', '-m', 'feat: add feature']);
  /// ```
  Future<CommandResult> exec(String executable, List<String> args,
      {WorkspaceOptions? options});

  /// Spawns a shell command as a background process.
  ///
  /// Returns immediately with a [WorkspaceProcess] handle for streaming
  /// stdout/stderr and waiting for completion.
  ///
  /// Example:
  /// ```
  /// final process = await ws.start('python app.py');
  /// await for (final line in process.stdout) {
  ///   print('Output: $line');
  /// }
  /// ```
  Future<WorkspaceProcess> start(String shellCommand,
      {WorkspaceOptions? options});

  /// Spawns a binary directly as a background process.
  ///
  /// Similar to [start] but executes the binary without shell interpretation.
  ///
  /// Example:
  /// ```
  /// final process = await ws.spawn('node', ['server.js']);
  /// final exitCode = await process.exitCode;
  /// ```
  Future<WorkspaceProcess> spawn(String executable, List<String> args,
      {WorkspaceOptions? options});

  // --- FILESYSTEM ---

  /// Writes text content to a file in the workspace.
  ///
  /// Creates parent directories if they don't exist.
  ///
  /// Example:
  /// ```
  /// await ws.writeFile('config.json', '{"debug": true}');
  /// ```
  Future<File> writeFile(String relativePath, String content);

  /// Reads text content from a file in the workspace.
  ///
  /// Throws [FileSystemException] if the file doesn't exist.
  Future<String> readFile(String relativePath);

  /// Writes binary data to a file in the workspace.
  Future<File> writeBytes(String relativePath, List<int> bytes);

  /// Reads binary data from a file in the workspace.
  Future<List<int>> readBytes(String relativePath);

  /// Creates a directory in the workspace.
  ///
  /// Creates parent directories recursively if needed.
  Future<Directory> createDir(String relativePath);

  /// Deletes a file or directory in the workspace.
  ///
  /// If the path is a directory, deletes recursively.
  Future<void> delete(String relativePath);

  /// Checks if a file or directory exists in the workspace.
  Future<bool> exists(String relativePath);

  // --- OBSERVABILITY ---

  /// Generates a visual tree representation of the workspace.
  ///
  /// Parameters:
  /// - [maxDepth]: Maximum directory depth to traverse (default: 5)
  ///
  /// Example output:
  /// ```
  /// workspace
  /// ├── src
  /// │   └── main.dart
  /// └── pubspec.yaml
  /// ```
  Future<String> tree({int maxDepth = 5});

  /// Searches for a text pattern in workspace files.
  ///
  /// Parameters:
  /// - [pattern]: Regular expression or literal string to search
  /// - [recursive]: Whether to search subdirectories (default: true)
  ///
  /// Returns lines matching the pattern with file paths.
  Future<String> grep(String pattern, {bool recursive = true});

  /// Finds files matching a glob pattern.
  ///
  /// Example:
  /// ```
  /// final dartFiles = await ws.find('**/*.dart');
  /// ```
  Future<List<String>> find(String pattern);

  /// Copies a file or directory within the workspace.
  Future<void> copy(String src, String dest);

  /// Moves a file or directory within the workspace.
  Future<void> move(String src, String dest);

  // --- LIFECYCLE ---

  /// Disposes the workspace and cleans up resources.
  ///
  /// For ephemeral workspaces, deletes the temporary directory.
  /// For persistent workspaces, only closes internal resources.
  ///
  /// Always call this when done with the workspace.
  Future<void> dispose();
}

/// Internal delegate implementation (not part of public API).
class _WorkspaceDelegate implements Workspace {
  final WorkspaceImpl _impl;
  final Directory _directory;
  final bool _isTemporary;

  _WorkspaceDelegate(this._directory, String id,
      {WorkspaceOptions? options, required bool isTemporary})
      : _isTemporary = isTemporary,
        _impl = WorkspaceImpl(_directory.path, id, options: options);

  @override
  String get rootPath => _directory.path;

  @override
  Stream<WorkspaceEvent> get onEvent => _impl.onEvent;

  @override
  Future<CommandResult> run(String cmd, {WorkspaceOptions? options}) =>
      _impl.run(cmd, options: options);

  @override
  Future<CommandResult> exec(String exe, List<String> args,
          {WorkspaceOptions? options}) =>
      _impl.exec(exe, args, options: options);

  @override
  Future<WorkspaceProcess> start(String cmd, {WorkspaceOptions? options}) =>
      _impl.start(cmd, options: options);

  @override
  Future<WorkspaceProcess> spawn(String exe, List<String> args,
          {WorkspaceOptions? options}) =>
      _impl.spawn(exe, args, options: options);

  @override
  Future<File> writeFile(String p, String c) => _impl.fs.writeFile(p, c);

  @override
  Future<String> readFile(String p) => _impl.fs.readFile(p);

  @override
  Future<File> writeBytes(String p, List<int> b) => _impl.fs.writeBytes(p, b);

  @override
  Future<List<int>> readBytes(String p) => _impl.fs.readBytes(p);

  @override
  Future<Directory> createDir(String p) => _impl.fs.createDir(p);

  @override
  Future<void> delete(String p) => _impl.fs.delete(p);

  @override
  Future<bool> exists(String p) => _impl.fs.exists(p);

  @override
  Future<String> tree({int maxDepth = 5}) => _impl.fs.tree(maxDepth: maxDepth);

  @override
  Future<String> grep(String pat, {bool recursive = true}) =>
      _impl.fs.grep(pat, recursive: recursive);

  @override
  Future<List<String>> find(String pat) => _impl.fs.find(pat);

  @override
  Future<void> copy(String s, String d) => _impl.fs.copy(s, d);

  @override
  Future<void> move(String s, String d) => _impl.fs.move(s, d);

  @override
  Future<void> dispose() async {
    await _impl.dispose();
    if (_isTemporary && await _directory.exists()) {
      try {
        await _directory.delete(recursive: true);
      } catch (_) {}
    }
  }
}

/// Generates a random 8-character alphanumeric ID.
String _generateId() {
  final rnd = Random();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
}

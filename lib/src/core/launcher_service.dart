import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/workspace_options.dart';
import '../models/workspace_process.dart';
import '../native/native_process_impl.dart';
import 'shell_wrapper.dart';

/// Service responsible for spawning processes via the native launcher binary.
///
/// This service acts as a bridge between Dart and the Rust-based native
/// launcher, handling argument serialization and process lifecycle management.
///
/// The launcher binary provides cross-platform sandboxing using:
/// - **Linux**: Bubblewrap (bwrap)
/// - **Windows**: Job Objects
/// - **macOS**: Seatbelt (sandbox-exec)
class LauncherService {
  /// Root directory path of the workspace.
  final String rootPath;

  /// Unique identifier for this workspace instance.
  final String id;

  /// Creates a new launcher service for the given workspace.
  ///
  /// Parameters:
  /// - [rootPath]: Must be an absolute path to an existing directory
  /// - [id]: Should be unique across concurrent workspace instances
  LauncherService(this.rootPath, this.id);

  /// Spawns a command wrapped in the system shell.
  ///
  /// The [commandLine] is executed through the platform's default shell
  /// (`/bin/sh` on Unix, `cmd.exe` on Windows), allowing use of shell features
  /// like pipes, redirections, and environment variable expansion.
  ///
  /// Returns a [WorkspaceProcess] handle for managing the spawned process.
  ///
  /// Example:
  /// ```
  /// final process = await launcher.spawnShell(
  ///   'grep "error" app.log | wc -l',
  ///   WorkspaceOptions(),
  /// );
  /// ```
  Future<WorkspaceProcess> spawnShell(
      String commandLine, WorkspaceOptions options) async {
    final shellArgs = ShellWrapper.wrap(commandLine);
    return _spawnInternal(shellArgs, options);
  }

  /// Spawns a binary directly with explicit arguments.
  ///
  /// Unlike [spawnShell], this method executes the binary directly without
  /// shell interpretation, providing better security and avoiding shell
  /// injection vulnerabilities.
  ///
  /// Returns a [WorkspaceProcess] handle for managing the spawned process.
  ///
  /// Example:
  /// ```
  /// final process = await launcher.spawnExec(
  ///   'git',
  ///   ['commit', '-m', 'feat: add feature'],
  ///   WorkspaceOptions(),
  /// );
  /// ```
  Future<WorkspaceProcess> spawnExec(
      String executable, List<String> args, WorkspaceOptions options) async {
    final flatArgs = [executable, ...args];
    return _spawnInternal(flatArgs, options);
  }

  /// Internal method that spawns the native launcher with serialized arguments.
  Future<WorkspaceProcess> _spawnInternal(
      List<String> commandArgs, WorkspaceOptions options) async {
    final launcherPath = await _findBinary();
    final nativeArgs = _buildNativeArgs(options, commandArgs);

    final process = await Process.start(
      launcherPath,
      nativeArgs,
      mode: ProcessStartMode.normal,
    );

    return NativeProcessImpl(process, timeout: options.timeout);
  }

  /// Builds the argument list for the native launcher binary.
  ///
  /// Serializes workspace configuration and command arguments into a format
  /// understood by the Rust launcher.
  ///
  /// Arguments include:
  /// - Workspace ID and root path
  /// - Sandbox and network flags
  /// - Working directory override
  /// - Environment variables
  /// - Command and arguments
  List<String> _buildNativeArgs(
      WorkspaceOptions opts, List<String> commandArgs) {
    final args = ['--id', id, '--workspace', rootPath];

    if (opts.sandbox) args.add('--sandbox');
    if (!opts.allowNetwork) args.add('--no-net');

    if (opts.workingDirectoryOverride != null) {
      final absCwd = p.join(rootPath, opts.workingDirectoryOverride!);
      args.addAll(['--cwd', absCwd]);
    }

    final env = <String, String>{};
    if (opts.includeParentEnv) env.addAll(Platform.environment);
    env.addAll(opts.env);
    env.forEach((k, v) => args.addAll(['--env', '$k=$v']));

    args.add('--');
    args.addAll(commandArgs);

    return args;
  }

  /// Locates the native launcher binary for the current platform.
  ///
  /// Searches in the following order:
  /// 1. Development build: `native/target/release/workspace_launcher`
  /// 2. Production build: `bin/<os>/x64/workspace_launcher`
  /// 3. Package installation: relative to the Dart script location
  ///
  /// Throws [UnsupportedError] if the current platform is not supported.
  /// Throws [StateError] if the binary cannot be found in any location.
  Future<String> _findBinary() async {
    String osFolder;
    String binName = 'workspace_launcher';

    if (Platform.isWindows) {
      osFolder = 'windows';
      binName = '$binName.exe';
    } else if (Platform.isLinux) {
      osFolder = 'linux';
    } else if (Platform.isMacOS) {
      osFolder = 'macos';
    } else {
      throw UnsupportedError(
          'Platform "${Platform.operatingSystem}" is not supported. '
          'Supported platforms: Windows, Linux, macOS');
    }

    final devBuild =
        p.join(Directory.current.path, 'native', 'target', 'release', binName);
    if (await File(devBuild).exists()) return devBuild;

    final prodBuild =
        p.join(Directory.current.path, 'bin', osFolder, 'x64', binName);
    if (await File(prodBuild).exists()) return prodBuild;

    final scriptDir = p.dirname(Platform.script.toFilePath());
    final pkgBuild = p.join(scriptDir, 'bin', osFolder, 'x64', binName);
    if (await File(pkgBuild).exists()) return pkgBuild;

    throw StateError(
        'Launcher binary "$binName" not found. Searched locations:\n'
        '  1. $devBuild\n'
        '  2. $prodBuild\n'
        '  3. $pkgBuild\n'
        'Ensure the native binaries are built or included in the package.');
  }
}

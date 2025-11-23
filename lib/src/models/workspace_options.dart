import 'dart:async';

/// Cooperative cancellation token for running processes.
///
/// Allows external cancellation of long-running processes without directly
/// killing them. Processes can listen to [onCancel] and perform graceful
/// cleanup before terminating.
///
/// Example:
/// ```
/// final token = CancellationToken();
///
/// // In another part of the code:
/// Timer(Duration(seconds: 5), () => token.cancel());
///
/// final result = await ws.run(
///   'long_running_task.sh',
///   options: WorkspaceOptions(cancellationToken: token),
/// );
/// ```
class CancellationToken {
  final _controller = StreamController<void>.broadcast();
  bool _isCancelled = false;

  /// Creates a new cancellation token.
  CancellationToken();

  /// Whether this token has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Stream that emits when cancellation is requested.
  ///
  /// Listeners can use this to perform graceful shutdown.
  Stream<void> get onCancel => _controller.stream;

  /// Requests cancellation and notifies all listeners.
  ///
  /// This is idempotent - calling it multiple times has no additional effect.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _controller.add(null);
    _controller.close();
  }
}

/// Configuration options for running commands in a workspace.
///
/// Allows customization of:
/// - Execution timeout
/// - Environment variables
/// - Working directory
/// - Sandboxing and network access
///
/// Example:
/// ```
/// final result = await ws.run(
///   'npm install',
///   options: WorkspaceOptions(
///     timeout: Duration(minutes: 5),
///     env: {'NODE_ENV': 'production'},
///     allowNetwork: true,
///   ),
/// );
/// ```
class WorkspaceOptions {
  /// Maximum time allowed for command execution.
  ///
  /// If the process exceeds this duration, it will be killed and
  /// [CommandResult.isCancelled] will be `true`.
  final Duration? timeout;

  /// Additional environment variables to inject into the process.
  ///
  /// These are merged with parent environment variables if
  /// [includeParentEnv] is `true`.
  final Map<String, String> env;

  /// Whether to inherit environment variables from the parent process.
  ///
  /// When `true` (default), the process receives all environment variables
  /// from the Dart process, plus any additional ones from [env].
  final bool includeParentEnv;

  /// Optional cancellation token for cooperative process termination.
  final CancellationToken? cancellationToken;

  /// Override the working directory for command execution.
  ///
  /// If provided, this path is resolved relative to the workspace root.
  /// If `null`, commands execute from the workspace root.
  ///
  /// Example:
  /// ```
  /// await ws.run('npm test', options: WorkspaceOptions(
  ///   workingDirectoryOverride: 'packages/core',
  /// ));
  /// ```
  final String? workingDirectoryOverride;

  /// Whether to enable native sandboxing (bubblewrap/JobObject/Seatbelt).
  ///
  /// When `true`, commands are isolated from the host system using
  /// platform-specific sandboxing mechanisms.
  final bool sandbox;

  /// Whether to allow network access from sandboxed processes.
  ///
  /// Only applies when [sandbox] is `true`. When `false`, network access
  /// is blocked at the sandbox level.
  final bool allowNetwork;

  /// Creates workspace execution options.
  const WorkspaceOptions({
    this.timeout,
    this.env = const {},
    this.includeParentEnv = true,
    this.cancellationToken,
    this.workingDirectoryOverride,
    this.sandbox = false,
    this.allowNetwork = true,
  });

  /// Creates a copy of these options with the given fields replaced.
  ///
  /// Example:
  /// ```
  /// final baseOptions = WorkspaceOptions(timeout: Duration(seconds: 30));
  /// final networkOptions = baseOptions.copyWith(allowNetwork: false);
  /// ```
  WorkspaceOptions copyWith({
    Duration? timeout,
    Map<String, String>? env,
    bool? includeParentEnv,
    CancellationToken? cancellationToken,
    String? workingDirectoryOverride,
    bool? sandbox,
    bool? allowNetwork,
  }) {
    return WorkspaceOptions(
      timeout: timeout ?? this.timeout,
      env: env ?? this.env,
      includeParentEnv: includeParentEnv ?? this.includeParentEnv,
      cancellationToken: cancellationToken ?? this.cancellationToken,
      workingDirectoryOverride:
          workingDirectoryOverride ?? this.workingDirectoryOverride,
      sandbox: sandbox ?? this.sandbox,
      allowNetwork: allowNetwork ?? this.allowNetwork,
    );
  }
}

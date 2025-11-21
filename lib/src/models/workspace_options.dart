import 'dart:async';

/// Cooperative cancellation token for running processes.
///
/// A [CancellationToken] can be passed to [WorkspaceOptions] to allow
/// programmatic cancellation of long‑running commands.
class CancellationToken {
  final _controller = StreamController<void>.broadcast();
  bool _isCancelled = false;

  /// Whether [cancel] has already been requested.
  bool get isCancelled => _isCancelled;

  /// Stream that fires once when [cancel] is called.
  Stream<void> get onCancel => _controller.stream;

  /// Requests cancellation for any operation that is listening to [onCancel].
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _controller.add(null);
    _controller.close();
  }
}

/// Configuration options for running a command inside a workspace.
///
/// These options control environment variables, working directory,
/// timeouts and optional sandboxing.
class WorkspaceOptions {
  /// Maximum execution time before the process is killed.
  ///
  /// If `null`, no timeout is enforced by the library.
  final Duration? timeout;

  /// Additional environment variables to inject into the process.
  ///
  /// When [includeParentEnv] is `true`, these are merged on top of the
  /// host process environment.
  final Map<String, String> env;

  /// Whether to inherit the parent process environment variables.
  ///
  /// When `true`, [env] extends the existing environment instead of
  /// replacing it.
  final bool includeParentEnv;

  /// Optional cooperative cancellation token.
  ///
  /// If provided, long‑running operations can observe this token and
  /// terminate early when [CancellationToken.cancel] is invoked.
  final CancellationToken? cancellationToken;

  /// Optional working directory override.
  ///
  /// When `null`, the workspace root directory is used as the cwd.
  final String? workingDirectoryOverride;

  /// Indicates whether this execution should be sandboxed.
  ///
  /// The exact semantics are defined by the native implementation and
  /// may evolve over time.
  final bool sandbox;

  /// Creates a new immutable set of options for process execution.
  const WorkspaceOptions({
    this.timeout,
    this.env = const {},
    this.includeParentEnv = true,
    this.cancellationToken,
    this.workingDirectoryOverride,
    this.sandbox = false,
  });
}

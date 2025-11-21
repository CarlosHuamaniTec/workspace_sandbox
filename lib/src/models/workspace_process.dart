import 'dart:async';

/// Represents a running process inside a workspace.
///
/// Exposes stdout and stderr as streams and allows callers to await
/// completion or terminate the process.
abstract class WorkspaceProcess {
  /// Real‑time stream of standard output from the process.
  Stream<String> get stdout;

  /// Real‑time stream of standard error from the process.
  Stream<String> get stderr;

  /// Completes when the process exits, yielding its exit code.
  Future<int> get exitCode;

  /// Attempts to terminate the underlying process.
  ///
  /// On Unix platforms this typically maps to SIGTERM, while on
  /// Windows it maps to `TerminateProcess`.
  void kill();
}

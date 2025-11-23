import 'dart:async';

/// Represents a running process inside a workspace.
///
/// Provides access to the process's output streams and allows waiting for
/// completion or manually terminating the process.
///
/// This is returned by [Workspace.start] and [Workspace.spawn] for
/// background process execution.
///
/// Example:
/// ```
/// final process = await ws.start('tail -f app.log');
///
/// // Stream output in real-time
/// await for (final line in process.stdout) {
///   print('LOG: $line');
/// }
///
/// // Or wait for completion
/// final exitCode = await process.exitCode;
/// ```
abstract class WorkspaceProcess {
  /// Real-time stream of standard output from the process.
  ///
  /// This stream is broadcast and can have multiple listeners.
  /// It emits chunks of text as they are received from the process.
  Stream<String> get stdout;

  /// Real-time stream of standard error from the process.
  ///
  /// This stream is broadcast and can have multiple listeners.
  /// It emits error messages and diagnostic output as they are received.
  Stream<String> get stderr;

  /// Completes when the process exits, yielding its exit code.
  ///
  /// The exit code is platform-specific, but typically `0` indicates
  /// success and non-zero values indicate errors.
  Future<int> get exitCode;

  /// Whether the process was cancelled by timeout or manual termination.
  ///
  /// This is `true` if [kill] was called or if the process was terminated
  /// by a timeout.
  bool get isCancelled;

  /// Attempts to terminate the underlying process.
  ///
  /// Sends SIGTERM on Unix platforms and calls `TerminateProcess` on Windows.
  /// After a brief delay (250ms), sends SIGKILL on Unix to force termination
  /// if the process hasn't exited.
  ///
  /// Example:
  /// ```
  /// final process = await ws.start('sleep 100');
  /// await Future.delayed(Duration(seconds: 2));
  /// process.kill(); // Terminate early
  /// ```
  void kill();
}

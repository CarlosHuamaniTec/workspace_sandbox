/// Final result of a command executed inside a workspace.
///
/// This is similar in spirit to [ProcessResult] from `dart:io`, but
/// tailored to the workspace API and with an explicit [duration]
/// and [isCancelled] flag.
class CommandResult {
  /// Exit code returned by the process.
  ///
  /// By convention, `0` usually indicates success.
  final int exitCode;

  /// Captured standard output (stdout) as text.
  final String stdout;

  /// Captured standard error (stderr) as text.
  final String stderr;

  /// Total time spent executing the command.
  final Duration duration;

  /// Whether the process was cancelled by the user or a timeout.
  ///
  /// When `true`, callers should treat this result as incomplete, even
  /// if [exitCode] is non‑zero.
  final bool isCancelled;

  /// Creates an immutable command execution result.
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    this.isCancelled = false,
  });

  /// Convenience flag indicating whether [exitCode] equals `0`.
  bool get isSuccess => exitCode == 0;

  @override
  String toString() {
    return 'CommandResult('
        'exitCode: $exitCode, '
        'success: $isSuccess, '
        'duration: ${duration.inMilliseconds}ms'
        ')';
  }
}

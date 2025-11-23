/// Final result of a command executed inside a workspace.
///
/// Similar to [ProcessResult] from `dart:io`, but tailored for the workspace
/// API with additional fields for execution duration and cancellation status.
///
/// Example:
/// ```
/// final result = await ws.run('ls -la');
/// if (result.isSuccess) {
///   print(result.stdout);
/// } else {
///   print('Failed: ${result.stderr}');
/// }
/// ```
class CommandResult {
  /// Exit code returned by the process.
  ///
  /// By convention, `0` indicates success, and non-zero values indicate errors.
  final int exitCode;

  /// Captured standard output (stdout) as text.
  ///
  /// This is the complete output accumulated during process execution.
  final String stdout;

  /// Captured standard error (stderr) as text.
  ///
  /// Contains error messages and diagnostic output from the process.
  final String stderr;

  /// Total time spent executing the command.
  ///
  /// Measured from process start to exit.
  final Duration duration;

  /// Whether the process was cancelled by timeout or manual termination.
  ///
  /// When `true`, the result should be treated as incomplete even if
  /// [exitCode] is set.
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

  /// Convenience flag indicating whether [exitCode] is NOT `0`.
  bool get isFailure => exitCode != 0;

  @override
  String toString() {
    return 'CommandResult('
        'exitCode: $exitCode, '
        'success: $isSuccess, '
        'duration: ${duration.inMilliseconds}ms'
        ')';
  }
}

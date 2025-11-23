/// Base class for all events occurring within a workspace.
///
/// Events are emitted through the [Workspace.onEvent] stream to provide
/// real-time visibility into process execution and output.
///
/// See also:
/// - [ProcessOutputEvent]: Emitted when a process writes to stdout/stderr
/// - [ProcessLifecycleEvent]: Emitted when a process starts or stops
sealed class WorkspaceEvent {
  /// Timestamp when this event was created.
  final DateTime timestamp = DateTime.now();

  /// Unique identifier of the workspace that generated this event.
  final String workspaceId;

  /// Creates a workspace event.
  WorkspaceEvent(this.workspaceId);
}

/// Emitted when a process outputs text to stdout or stderr.
///
/// This event is fired for each chunk of output received from the process,
/// allowing real-time streaming of command output.
///
/// Example:
/// ```
/// ws.onEvent.listen((event) {
///   if (event is ProcessOutputEvent) {
///     print(event.isError ? 'ERROR: ' : 'OUTPUT: ');
///     print(event.content);
///   }
/// });
/// ```
class ProcessOutputEvent extends WorkspaceEvent {
  /// Process identifier (PID).
  final int pid;

  /// The original command that spawned this process.
  final String command;

  /// The text content output by the process.
  final String content;

  /// Whether this output came from stderr (`true`) or stdout (`false`).
  final bool isError;

  /// Creates a process output event.
  ProcessOutputEvent({
    required String workspaceId,
    required this.pid,
    required this.command,
    required this.content,
    required this.isError,
  }) : super(workspaceId);

  @override
  String toString() => '[${isError ? "ERR" : "OUT"}] $content';
}

/// Emitted when a process changes lifecycle state.
///
/// Fires when a process starts, stops, or fails, providing visibility into
/// the process execution lifecycle.
///
/// Example:
/// ```
/// ws.onEvent.listen((event) {
///   if (event is ProcessLifecycleEvent) {
///     print('Process ${event.pid}: ${event.state.name}');
///     if (event.state == ProcessState.stopped) {
///       print('Exit code: ${event.exitCode}');
///     }
///   }
/// });
/// ```
class ProcessLifecycleEvent extends WorkspaceEvent {
  /// Process identifier (PID).
  final int pid;

  /// The original command that spawned this process.
  final String command;

  /// The current lifecycle state of the process.
  final ProcessState state;

  /// Exit code of the process (only available when [state] is [ProcessState.stopped]).
  final int? exitCode;

  /// Creates a process lifecycle event.
  ProcessLifecycleEvent({
    required String workspaceId,
    required this.pid,
    required this.command,
    required this.state,
    this.exitCode,
  }) : super(workspaceId);

  @override
  String toString() =>
      '[LIFECYCLE] Process $pid ($command) -> ${state.name} ${exitCode != null ? "(Code $exitCode)" : ""}';
}

/// Lifecycle states of a process.
enum ProcessState {
  /// Process has been spawned and is running.
  started,

  /// Process has exited normally.
  stopped,

  /// Process has failed to start or crashed.
  failed,
}

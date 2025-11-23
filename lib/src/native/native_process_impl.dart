import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/workspace_process.dart';

/// Native process implementation that wraps [Process] with stream management.
///
/// Handles:
/// - UTF-8 decoding with malformed byte tolerance (for Windows CP850/ANSI)
/// - Timeout management with graceful and forceful termination
/// - Broadcast streams for stdout/stderr to allow multiple listeners
class NativeProcessImpl implements WorkspaceProcess {
  final Process _process;
  final _stdoutCtrl = StreamController<String>.broadcast();
  final _stderrCtrl = StreamController<String>.broadcast();
  final _exitCodeCompleter = Completer<int>();

  Timer? _timeoutTimer;
  bool _isCancelled = false;

  /// Creates a native process wrapper with optional timeout.
  ///
  /// If [timeout] is provided, the process will be killed automatically
  /// after the duration elapses.
  ///
  /// The stdout/stderr streams are immediately attached and decoded as UTF-8
  /// with malformed byte tolerance to handle non-Unicode output (e.g.,
  /// Windows console apps using CP850 encoding).
  NativeProcessImpl(this._process, {Duration? timeout}) {
    const decoder = Utf8Decoder(allowMalformed: true);

    _process.stdout.transform(decoder).listen((data) => _stdoutCtrl.add(data),
        onDone: () => _stdoutCtrl.close(),
        onError: (e) => _stdoutCtrl.add('[Stream Error: $e]'));

    _process.stderr.transform(decoder).listen((data) => _stderrCtrl.add(data),
        onDone: () => _stderrCtrl.close(),
        onError: (e) => _stderrCtrl.add('[Stream Error: $e]'));

    _process.exitCode.then((code) {
      if (!_exitCodeCompleter.isCompleted) {
        _exitCodeCompleter.complete(code);
      }
      _timeoutTimer?.cancel();
    });

    if (timeout != null) {
      _timeoutTimer = Timer(timeout, () {
        kill();
        if (!_stderrCtrl.isClosed) {
          _stderrCtrl.add('\n[timeout]\n');
        }
      });
    }
  }

  @override
  Stream<String> get stdout => _stdoutCtrl.stream;

  @override
  Stream<String> get stderr => _stderrCtrl.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  bool get isCancelled => _isCancelled;

  @override
  void kill() {
    if (_isCancelled) return;
    _isCancelled = true;

    _process.kill(ProcessSignal.sigterm);

    Timer(const Duration(milliseconds: 250), () {
      _process.kill(ProcessSignal.sigkill);
    });
  }
}

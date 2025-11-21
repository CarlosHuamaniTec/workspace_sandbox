import 'dart:io';

import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace.dart';

void main() {
  group('Core integration', () {
    late Workspace ws;

    setUp(() {
      ws = Workspace.host(Directory.current.path);
    });

    tearDown(() async {
      await ws.dispose();
    });

    test('executes a real command (dart --version)', () async {
      final result = await ws.run('${Platform.executable} --version');

      final output = result.stdout.isEmpty ? result.stderr : result.stdout;

      expect(
        result.exitCode,
        0,
        reason: 'Process failed. Stderr: ${result.stderr}',
      );
      expect(output, contains('Dart SDK version'));
    });

    test('fails gracefully for a non-existent command', () async {
      final result = await ws.run('non_existent_command_123_xyz');

      expect(result.isSuccess, isFalse);
      expect(result.exitCode, isNot(0));
      expect(
        result.stderr,
        anyOf(
          contains('Native start failed'),
          contains('Failed to start process'),
        ),
      );
    });

    test('respects and triggers timeout', () async {
      final cmd = Platform.isWindows ? 'ping 127.0.0.1 -n 4' : 'sleep 3';

      final stopwatch = Stopwatch()..start();
      final result = await ws.run(
        cmd,
        options: const WorkspaceOptions(
          timeout: Duration(seconds: 1),
        ),
      );
      stopwatch.stop();

      expect(
        result.isCancelled,
        isTrue,
        reason: 'Process did not report as cancelled.',
      );
      expect(
        result.stderr,
        contains('process timeout exceeded'),
        reason: 'Timeout error message not found in stderr.',
      );
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 2)),
        reason: 'Process ran longer than the timeout.',
      );
    });
  });
}

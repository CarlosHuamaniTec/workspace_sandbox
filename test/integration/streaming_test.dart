import 'dart:async';
import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Workspace Streaming (Native Batch)', () {
    late Workspace ws;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('workspace_stream_test_');
      ws = Workspace.host(tempDir.path);
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('Should execute native script (.bat/.sh) and stream output', () async {
      String scriptName;

      if (Platform.isWindows) {
        scriptName = 'test_run.bat';
        await File(p.join(tempDir.path, scriptName)).writeAsString('''
          @echo off
          echo INIT_DATA
          ping 127.0.0.1 -n 2 > nul
          echo MIDDLE_DATA
          ping 127.0.0.1 -n 2 > nul
          echo FINAL_DATA
        ''');
      } else {
        scriptName = 'test_run.sh';
        final shFile = File(p.join(tempDir.path, scriptName));
        await shFile.writeAsString('''
          #!/bin/sh
          echo "INIT_DATA"
          sleep 1
          echo "MIDDLE_DATA"
          sleep 1
          echo "FINAL_DATA"
        ''');
        await Process.run('chmod', ['+x', shFile.path]);
      }

      // On Windows, we invoke the script directly. The library should handle execution.
      // On Linux, we use ./ prefix.
      final cmd = Platform.isWindows ? scriptName : './$scriptName';

      final process = await ws.start(cmd);
      final logs = <String>[];
      final completer = Completer<void>();

      process.stdout.listen((data) {
        final line = data.trim();
        if (line.isNotEmpty) {
          logs.add(line);
          if (line.contains('FINAL_DATA') && !completer.isCompleted) {
            completer.complete();
          }
        }
      });

      try {
        await completer.future.timeout(Duration(seconds: 10));
      } catch (e) {
        process.kill();
        fail("Timeout waiting for script output. Logs received: $logs");
      }

      expect(logs, contains('INIT_DATA'));
      expect(logs, contains('MIDDLE_DATA'));
      expect(logs, contains('FINAL_DATA'));

      process.kill();
    });
  });
}

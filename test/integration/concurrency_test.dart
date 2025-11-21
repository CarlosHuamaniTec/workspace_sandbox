import 'dart:async';
import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace.dart';

void main() {
  group('Concurrency & Stress Tests', () {
    test('Should handle multiple concurrent workspaces without data crossover',
        () async {
      const int instanceCount = 10;
      print('--- Starting $instanceCount Concurrent Agents ---');

      final futures = <Future<void>>[];
      for (int i = 0; i < instanceCount; i++) {
        futures.add(_runAgentSimulation(i));
      }

      await Future.wait(futures);
      print('✅ All agents completed successfully.');
    });
  });
}

Future<void> _runAgentSimulation(int id) async {
  final ws = Workspace.secure();
  final uniqueSecret = 'SecretData_Agent_$id';

  try {
    // 1. Write unique file
    await ws.writeFile('memory.txt', uniqueSecret);

    // 2. Run process (simulate workload)
    final cmd = Platform.isWindows
        ? 'cmd /c echo Start $id & ping 127.0.0.1 -n 2 > nul & echo End $id'
        : 'sh -c "echo Start $id; sleep 1; echo End $id"';

    final proc = await ws.start(cmd);
    final logs = <String>[];

    // Listen silently
    proc.stdout.listen((line) => logs.add(line.trim()));
    await proc.exitCode;

    // 3. Validations
    if (logs.isEmpty || !logs.join().contains('End $id')) {
      throw Exception('Agent $id: Incomplete process flow. Logs: $logs');
    }

    final readContent = await ws.readFile('memory.txt');
    if (readContent != uniqueSecret) {
      throw Exception('Agent $id: Memory contamination! Read: $readContent');
    }
  } catch (e) {
    print('❌ Agent $id FAILED: $e');
    rethrow;
  } finally {
    await ws.dispose();
  }
}

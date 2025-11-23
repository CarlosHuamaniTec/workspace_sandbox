import 'dart:async';
import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() {
  test('Concurrency: 10 agents running simultaneously', () async {
    const agentCount = 10;

    final futures = List.generate(agentCount, (index) async {
      final ws = Workspace.ephemeral();
      try {
        final filename = 'agent_$index.txt';
        await ws.writeFile(filename, 'Data $index');

        final cmd = Platform.isWindows ? 'cmd /c echo $index' : 'echo $index';
        final result = await ws.run(cmd);
        expect(result.stdout.trim(), equals('$index'));

        final read = await ws.readFile(filename);
        expect(read, equals('Data $index'));
        return true;
      } finally {
        await ws.dispose();
      }
    });

    final results = await Future.wait(futures);
    expect(results.every((r) => r), isTrue);
  }, timeout: Timeout(Duration(seconds: 30)));
}

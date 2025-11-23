import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() {
  group('Workspace API', () {
    late Workspace ws;

    setUp(() {
      ws = Workspace.ephemeral();
    });

    tearDown(() async {
      await ws.dispose();
    });

    test('Should execute basic shell commands', () async {
      final result = await ws.run("echo OK");
      expect(result.exitCode, 0);
      expect(result.stdout.trim(), contains("OK"));
    });

    test('Should provide observability tools', () async {
      await ws.createDir('src/utils');
      await ws.writeFile('src/utils/helper.dart', '// helper');

      for (var i = 0; i < 20; i++) {
        final files = await ws.find('*.dart');
        if (files.contains(p.join('src', 'utils', 'helper.dart'))) {
          await Future.delayed(const Duration(milliseconds: 200));
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final tree = await ws.tree();
      expect(tree, contains('src'));
      expect(tree, contains('helper.dart'));
    });

    test('Should handle timeout gracefully', () async {
      final cmd = Platform.isWindows ? 'ping -n 10 127.0.0.1' : 'sleep 10';
      final stopwatch = Stopwatch()..start();

      final result = await ws.run(cmd,
          options: const WorkspaceOptions(timeout: Duration(seconds: 2)));
      stopwatch.stop();

      expect(result.isCancelled, isTrue);
      expect(stopwatch.elapsed.inSeconds, lessThan(5));
    });
  });
}

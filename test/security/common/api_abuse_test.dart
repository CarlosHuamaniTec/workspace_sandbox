import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() {
  group('API Abuse & Injection Attacks', () {
    late Workspace ws;

    setUp(() {
      ws = Workspace.ephemeral();
    });

    tearDown(() async {
      await ws.dispose();
    });

    test('Command Injection via Filename', () async {
      final maliciousFile = 'file.txt; echo INJECTED > /tmp/pwned.txt';

      await ws.writeFile('safe.txt', 'data');
      await ws.run('cat "$maliciousFile"');

      final pwnedFile = File('/tmp/pwned.txt');
      if (await pwnedFile.exists()) {
        await pwnedFile.delete();
        fail('CRITICAL: Command injection succeeded!');
      }
    });

    test('Path Traversal via API', () async {
      try {
        await ws.writeFile('../../../etc/hacked.txt', 'INJECTED');
        fail('API allowed path traversal!');
      } catch (e) {
        expect(e.toString(), contains('escape'));
      }
    });

    test('Disk Space Exhaustion', () async {
      final timeout = Duration(seconds: 1);
      final targetSize = 10000;

      final result = await ws.run(
          'dd if=/dev/zero of=bigfile bs=1M count=$targetSize',
          options: WorkspaceOptions(timeout: timeout));

      if (result.exitCode == 0) {
        final file = File('${ws.rootPath}/bigfile');
        final size = await file.length();
        expect(size, lessThan(targetSize * 1024 * 1024));
      } else {
        expect(true, isTrue);
      }
    });

    test('Resource Exhaustion', () async {
      final cmd = Platform.isWindows ? 'ping -n 10 127.0.0.1' : 'sleep 10';
      final stopwatch = Stopwatch()..start();

      final result = await ws.run(cmd,
          options: const WorkspaceOptions(timeout: Duration(seconds: 2)));
      stopwatch.stop();

      expect(stopwatch.elapsed.inMilliseconds, greaterThan(1500));
      expect(stopwatch.elapsed.inSeconds, lessThan(6));
      expect(result.isCancelled, isTrue);
    });
  });
}

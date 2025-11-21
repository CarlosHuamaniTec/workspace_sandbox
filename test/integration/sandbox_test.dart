import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace.dart';

void main() {
  group('AppContainer Sandbox (Windows)', () {
    late Workspace ws;

    setUp(() async {
      // Using a secure workspace ensures it's sandboxed by default
      ws = Workspace.secure();
    });

    tearDown(() async {
      await ws.dispose();
    });

    if (!Platform.isWindows) return;

    test('Should execute a simple command inside the sandbox', () async {
      // We pass the command directly. The library's ShellParser will wrap it in 'cmd /c'.
      final result = await ws.run('echo "Hello Sandbox"');

      expect(result.exitCode, 0,
          reason: "Process failed. Stderr: ${result.stderr}");
      expect(result.stdout, contains('Hello Sandbox'));
    });
  });
}

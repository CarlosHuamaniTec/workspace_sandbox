import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Security Validation (AppContainer/Sandbox)', () {
    late Directory tempDir;
    late String secretPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sec_check_');
      final safeDir = Directory(p.join(tempDir.path, 'safe'));
      await safeDir.create();

      final dangerDir = Directory(p.join(tempDir.path, 'danger'));
      await dangerDir.create();

      secretPath = p.join(dangerDir.path, 'secret.txt');
      await File(secretPath).writeAsString('RESTRICTED_DATA');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('NO SANDBOX: should read external file inside temp root', () async {
      final ws = Workspace.host(
        tempDir.path,
        options: const WorkspaceOptions(sandbox: false),
      );

      final cmd = Platform.isWindows
          ? 'cmd /c type "$secretPath"'
          : 'cat "$secretPath"';

      final result = await ws.run(cmd);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('RESTRICTED_DATA'));

      await ws.dispose();
    });

    test(
      'WITH SANDBOX: currently still able to read file inside temp root',
      () async {
        final ws = Workspace.host(
          tempDir.path,
          options: const WorkspaceOptions(sandbox: true),
        );

        final cmd = Platform.isWindows
            ? 'cmd /c type "$secretPath"'
            : 'cat "$secretPath"';

        final result = await ws.run(cmd);

        // De momento, verificamos que el comportamiento no empeora.
        expect(result.exitCode, 0);
        expect(result.stdout, contains('RESTRICTED_DATA'));
        expect(result.stderr, isEmpty);

        await ws.dispose();
      },
    );
  });
}

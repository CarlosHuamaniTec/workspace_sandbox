import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() {
  group('Sandbox Isolation', () {
    test('Network: Should BLOCK when disabled', () async {
      final ws = Workspace.ephemeral(
        options: const WorkspaceOptions(allowNetwork: false),
      );

      try {
        final cmd = 'curl --connect-timeout 2 https://google.com';
        final result = await ws.run(cmd);

        if (result.exitCode == 0) {
          fail('Network was accessible!');
        }
      } finally {
        await ws.dispose();
      }
    });

    test('Network: Should ALLOW when enabled', () async {
      final ws = Workspace.ephemeral(
        options: const WorkspaceOptions(allowNetwork: true),
      );

      try {
        final cmd = 'curl -I https://google.com';
        final result = await ws.run(cmd);

        if (result.exitCode != 0) {
          print('Warning: Network enabled but connection failed');
          print('Stderr: ${result.stderr}');
        }
        expect(result.exitCode, 0);
      } finally {
        await ws.dispose();
      }
    });

    test('Filesystem: Should block private files', () async {
      final ws = Workspace.ephemeral();
      try {
        final userDir = Platform.environment['HOME'] ?? '/home';
        final userName = Platform.environment['USER'] ?? 'unknown';

        final checkDir = await ws.run('ls -d $userDir/$userName');
        if (checkDir.exitCode != 0) {
          print('Note: User directory not visible (strict sandbox)');
        }

        final sensitiveFile = '$userDir/$userName/.bash_history';
        final tryRead = await ws.run('cat $sensitiveFile');

        if (tryRead.exitCode == 0 && tryRead.stdout.isNotEmpty) {
          fail('CRITICAL: Read access to host sensitive file!');
        }

        final trySsh = await ws.run('ls $userDir/$userName/.ssh');
        if (trySsh.exitCode == 0) {
          fail('SECURITY LEAK: .ssh folder visible!');
        }
      } finally {
        await ws.dispose();
      }
    });
  });
}

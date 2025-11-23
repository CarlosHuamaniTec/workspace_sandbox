import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

/// Demonstrates security features and isolation capabilities.
///
/// This example shows how to:
/// - Block network access with allowNetwork option
/// - Verify system file protection
/// - Test sandbox isolation boundaries
void main() async {
  print('Security Audit Demo\n');

  final ws = Workspace.ephemeral(
    options: const WorkspaceOptions(allowNetwork: false),
  );

  try {
    print('Test 1: Attempting network access (should fail)...');
    final netResult =
        await ws.run('curl -I https://google.com --connect-timeout 2');

    if (netResult.exitCode != 0) {
      print('Network blocked successfully.\n');
    } else {
      print('Security breach: Network was accessible.\n');
    }

    print('Test 2: Attempting to read system files (should fail)...');
    final target = Platform.isWindows
        ? r'C:\Windows\System32\drivers\etc\hosts'
        : '/etc/shadow';
    final fsResult =
        await ws.run(Platform.isWindows ? 'type $target' : 'cat $target');

    if (fsResult.exitCode != 0 || fsResult.stdout.isEmpty) {
      print('File system protected.\n');
    } else {
      print('Security breach: Read system file.\n');
    }
  } finally {
    await ws.dispose();
  }
}

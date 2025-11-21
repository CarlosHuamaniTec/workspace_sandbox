import 'dart:io';

import 'package:workspace_sandbox/workspace.dart';

/// Simple CLI that runs a single command inside a secure, sandboxed
/// temporary workspace. This is useful for validating that commands
/// run in isolation from the host file system.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run example/cli_sandboxed.dart "<command>"');
    exit(64); // usage error
  }

  final command = args.join(' ');

  // Secure, ephemeral workspace + sandbox enabled.
  final workspace = Workspace.secure(
    options: const WorkspaceOptions(
      sandbox: true,
      timeout: Duration(seconds: 30),
    ),
  );

  stdout.writeln('Running (sandboxed): $command');
  stdout.writeln('Workspace root: ${workspace.rootPath}');
  stdout.writeln('---');

  try {
    // Optionally, create some safe test files inside the workspace.
    await workspace.writeFile('sandbox_info.txt', 'Hello from sandbox!\n');

    final result = await workspace.run(command);

    stdout.writeln('exitCode: ${result.exitCode}');
    if (result.stdout.isNotEmpty) {
      stdout.writeln('stdout:');
      stdout.write(result.stdout);
    }
    if (result.stderr.isNotEmpty) {
      stdout.writeln('stderr:');
      stdout.write(result.stderr);
    }

    if (result.isCancelled) {
      stdout.writeln('Command was cancelled (timeout or kill).');
    }
  } finally {
    await workspace.dispose();
  }
}

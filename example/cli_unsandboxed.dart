import 'dart:io';

import 'package:workspace_sandbox/workspace.dart';

/// Simple CLI that runs a single command inside a host workspace
/// without sandboxing. Useful to compare behavior with the
/// sandboxed version in `cli_sandboxed.dart`.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run example/cli_unsandboxed.dart "<command>"');
    exit(64); // usage error
  }

  final command = args.join(' ');

  // Use the current directory as the workspace root.
  final workspace = Workspace.host(
    Directory.current.path,
    options: const WorkspaceOptions(sandbox: false),
  );

  stdout.writeln('Running (no sandbox): $command');
  stdout.writeln('Workspace root: ${workspace.rootPath}');
  stdout.writeln('---');

  try {
    final result = await workspace.run(
      command,
      options: const WorkspaceOptions(
        timeout: Duration(seconds: 30),
        sandbox: false,
      ),
    );

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

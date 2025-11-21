// example/cli_repl_sandboxed.dart

import 'dart:convert';
import 'dart:io';

import 'package:workspace_sandbox/workspace.dart';

/// Interactive REPL that runs commands inside a secure, sandboxed workspace.
///
/// Type shell commands and press Enter to execute them inside the sandbox.
/// Type `exit` or press Ctrl+D (EOF) to quit.
Future<void> main(List<String> args) async {
  final workspace = Workspace.secure(
    options: const WorkspaceOptions(
      sandbox: true,
      timeout: Duration(seconds: 60),
    ),
  );

  stdout.writeln('workspace_sandbox interactive shell (sandboxed)');
  stdout.writeln('Workspace root: ${workspace.rootPath}');
  stdout.writeln('Type commands to run inside the sandbox.');
  stdout.writeln('Type "exit" or press Ctrl+D to quit.');
  stdout.writeln('---');

  final input = stdin.transform(utf8.decoder).transform(const LineSplitter());

  try {
    await for (final line in input) {
      final command = line.trim();
      if (command.isEmpty) continue;
      if (command.toLowerCase() == 'exit') {
        stdout.writeln('Exiting sandbox shell.');
        break;
      }

      stdout.writeln('\n\$ $command');

      final result = await workspace.run(command);

      if (result.stdout.isNotEmpty) {
        stdout.writeln(result.stdout);
      }
      if (result.stderr.isNotEmpty) {
        stderr.writeln(result.stderr);
      }
      stdout.writeln('[exitCode: ${result.exitCode}]');
    }
  } finally {
    await workspace.dispose();
  }
}

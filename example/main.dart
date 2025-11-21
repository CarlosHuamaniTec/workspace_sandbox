import 'dart:io';

import 'package:workspace_sandbox/workspace.dart';

/// Simple example showing how to:
/// - Create a secure temporary workspace
/// - Write a file inside the workspace
/// - Run a shell command that reads that file
/// - Print the results
Future<void> main() async {
  // Create a secure, ephemeral workspace in the system temp directory.
  final workspace = Workspace.secure();

  try {
    // 1. Write a file inside the workspace root.
    await workspace.writeFile('hello.txt', 'Hello from workspace_sandbox!\n');

    // 2. Choose a cross‑platform command to print the file contents.
    final command =
        Platform.isWindows ? 'cmd /c type hello.txt' : 'cat hello.txt';

    // 3. Run the command with a 5‑second timeout.
    final result = await workspace.run(
      command,
      options: const WorkspaceOptions(
        timeout: Duration(seconds: 5),
        // Set this to true if you want to enforce native sandboxing.
        // sandbox: true,
      ),
    );

    // 4. Inspect the result.
    stdout.writeln('--- Command finished ---');
    stdout.writeln('exitCode: ${result.exitCode}');
    stdout.writeln('stdout:');
    stdout.write(result.stdout);
    if (result.stderr.isNotEmpty) {
      stdout.writeln('stderr:');
      stdout.write(result.stderr);
    }
  } finally {
    // 5. Always dispose the workspace to free resources.
    await workspace.dispose();
  }
}

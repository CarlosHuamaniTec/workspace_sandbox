import 'package:workspace_sandbox/workspace_sandbox.dart';

/// Demonstrates basic workspace operations.
///
/// This example shows how to:
/// - Create an ephemeral workspace
/// - Write files
/// - Execute shell commands
/// - Read command results
void main() async {
  final ws = Workspace.ephemeral();

  try {
    print('Workspace created at: ${ws.rootPath}');

    print('\nStep 1: Creating a file...');
    await ws.writeFile('hello.txt', 'Hello from Sandbox!');

    print('Step 2: Running a command...');
    final result = await ws.run('grep "Hello" hello.txt');

    if (result.exitCode == 0) {
      print('Command succeeded: ${result.stdout.trim()}');
    } else {
      print('Command failed: ${result.stderr}');
    }
  } finally {
    await ws.dispose();
    print('\nWorkspace cleaned up.');
  }
}

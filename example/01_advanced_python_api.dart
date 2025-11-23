import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

/// Demonstrates advanced Python/Django workflow with reactive logging.
///
/// This example shows how to:
/// - Create Python virtual environments
/// - Install packages with pip
/// - Use the event stream for real-time logging
/// - Execute complex multi-step workflows
void main() async {
  final ws = Workspace.ephemeral(
    options: const WorkspaceOptions(
      allowNetwork: true,
      timeout: Duration(minutes: 5),
    ),
  );

  ws.onEvent.listen((e) {
    if (e is ProcessOutputEvent) {
      stdout.write('[${e.command.split(' ').first}] ${e.content}');
    }
  });

  try {
    print('Installing Django...\n');

    if (Platform.isWindows) {
      await ws.run('python -m venv venv');
      await ws.exec(r'venv\Scripts\pip', ['install', 'Django']);
      await ws.exec(r'venv\Scripts\python',
          ['-m', 'django', 'startproject', 'demo', '.']);
    } else {
      await ws.run('python3 -m venv venv');
      await ws.exec('venv/bin/pip', ['install', 'Django']);
      await ws.exec(
          'venv/bin/python', ['-m', 'django', 'startproject', 'demo', '.']);
    }

    print('\nDjango installed successfully.');
  } catch (e) {
    print('Error: $e');
  } finally {
    await ws.dispose();
  }
}

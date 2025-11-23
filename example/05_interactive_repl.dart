import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

/// Demonstrates real-time output streaming from long-running processes.
///
/// This example shows how to:
/// - Stream stdout from a running process
/// - Handle real-time output for interactive applications
/// - Simulate REPL-like behavior with Python scripts
void main() async {
  print('Interactive Python REPL Simulation (Streaming Output)');

  final ws = Workspace.ephemeral();

  try {
    print('\nStep 1: Creating Python script with progressive output...');
    await ws.writeFile('script.py', '''
import time
import sys

print(">>> Initializing AI Model...", flush=True)
time.sleep(1)
print(">>> Loading weights...", flush=True)
time.sleep(1)

for i in range(1, 4):
    print(f"Step {i}/3: Processing data...", flush=True)
    time.sleep(0.5)

print(">>> Done! Result: 42", flush=True)
''');

    print('\nStep 2: Starting process (real-time stream)...');
    final python = await ws.start('python3 -u script.py');

    print('\n--- Output Stream ---');
    await python.stdout.forEach((chunk) {
      stdout.write('[STREAM] $chunk');
    });

    await python.exitCode;
    print('\n--- Process Finished ---');
  } catch (e) {
    print('Error: $e');
  } finally {
    await ws.dispose();
  }
}

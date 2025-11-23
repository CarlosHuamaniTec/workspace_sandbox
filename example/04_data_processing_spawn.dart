import 'dart:io';
import 'dart:typed_data';
import 'package:workspace_sandbox/workspace_sandbox.dart';

/// Demonstrates concurrent task execution using spawn.
///
/// This example shows how to:
/// - Write binary data to files
/// - Spawn background processes without blocking
/// - Process large files asynchronously
void main() async {
  print('Data Processing Pipeline (Spawn & Binary IO)');

  final ws = Workspace.ephemeral();

  ws.onEvent.listen((e) {
    if (e is ProcessLifecycleEvent) {
      print('Event: ${e.command} -> ${e.state.name}');
    }
  });

  try {
    print('\nStep 1: Generating binary data (10MB)...');
    final largeData = Uint8List(10 * 1024 * 1024);
    await ws.writeBytes('raw_data.bin', largeData);

    final fileSize =
        await File('${ws.rootPath}/raw_data.bin').length() / 1024 / 1024;
    print('File created: $fileSize MB');

    print('\nStep 2: Spawning compression process (background)...');
    final zipProcess =
        await ws.spawn('tar', ['-czf', 'data.tar.gz', 'raw_data.bin']);

    print('Main thread is free while compressing...');
    await Future.delayed(Duration(seconds: 1));
    print('Doing other work...');

    await zipProcess.exitCode;
    print('Compression finished.');

    print('\nStep 3: Verifying compressed file...');
    if (await ws.exists('data.tar.gz')) {
      final size = await File('${ws.rootPath}/data.tar.gz').length() / 1024;
      print('Compressed file exists. Size: $size KB');
    } else {
      print('Error: Output file missing.');
    }
  } finally {
    await ws.dispose();
  }
}

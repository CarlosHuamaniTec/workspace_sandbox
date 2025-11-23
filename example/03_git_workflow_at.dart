import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

/// Demonstrates persistent workspace usage with Git automation.
///
/// This example shows how to:
/// - Use Workspace.at() to work on an existing directory
/// - Execute Git commands for version control
/// - Preserve files after workspace disposal
void main() async {
  print('Git Workflow Automation (Persistent Workspace)');

  final projectDir = Directory('${Directory.current.path}/example_repo');
  if (!projectDir.existsSync()) projectDir.createSync();

  final ws = Workspace.at(projectDir.path);

  ws.onEvent.listen((e) {
    if (e is ProcessOutputEvent) {
      stdout.write('[${e.command.split(' ').first}] ${e.content}');
    }
  });

  try {
    print('\nStep 1: Initializing Git repository...');
    await ws.run('git init');
    await ws.run('git config user.email "agent@bot.com"');
    await ws.run('git config user.name "Agent Bot"');

    print('\nStep 2: Creating content...');
    await ws.writeFile(
        'README.md', '# Auto-Generated Project\nManaged by Workspace Sandbox.');
    await ws.writeFile('src/main.dart', 'void main() { print("Hello"); }');

    print('\nProject Structure:');
    print(await ws.tree());

    print('\nStep 3: Committing changes...');
    await ws.exec('git', ['add', '.']);
    await ws.exec('git', ['commit', '-m', 'feat: Initial structure']);

    print('\nStep 4: Verifying Git log...');
    final log = await ws.run('git log --oneline');
    print('\nGit Log:\n${log.stdout}');
  } catch (e) {
    print('Error: $e');
  } finally {
    await ws.dispose();
    print('\nDone. Files preserved in ${ws.rootPath}');
  }
}

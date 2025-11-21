import 'dart:io';

/// Helpers to normalize shell commands before native execution.
///
/// On Windows this ensures that shell built‑ins, batch scripts and
/// commands using pipes or redirections are executed via `cmd.exe`.
/// On Unix‑like systems the command is currently returned as‑is.
class ShellParser {
  /// Set of common shell built‑ins and aliases that require a shell on Windows.
  static const _shellBuiltins = {
    'echo',
    'dir',
    'ls',
    'del',
    'rm',
    'mkdir',
    'cd',
    'copy',
    'cp',
    'move',
    'mv',
    'type',
    'cat',
    'cls',
    'clear',
  };

  /// Prepares the final command string for native execution.
  ///
  /// Throws if [command] is empty or whitespace only.
  ///
  /// On Windows:
  /// - If the command already starts with `cmd` / `cmd.exe`, it is returned as‑is.
  /// - If the first token is a shell built‑in or a `.bat` / `.cmd` script,
  ///   or the command contains `|` or `>`, it is wrapped in:
  ///   `cmd.exe /s /c "<original command>"`.
  ///
  /// On other platforms the command is currently returned unchanged.
  static String prepareCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) {
      throw Exception('Command cannot be empty.');
    }

    if (Platform.isWindows) {
      final binary = trimmed.split(' ').first.toLowerCase().replaceAll('"', '');
      final isScript = binary.endsWith('.bat') || binary.endsWith('.cmd');

      // If the command already starts with cmd.exe, leave it untouched.
      if (binary == 'cmd' || binary == 'cmd.exe') {
        return trimmed;
      }

      // For internal shell commands, scripts, or pipelines/redirects,
      // we must wrap the whole command in cmd.exe.
      if (isScript ||
          _shellBuiltins.contains(binary) ||
          trimmed.contains('|') ||
          trimmed.contains('>')) {
        return 'cmd.exe /s /c "$trimmed"';
      }
    } else {
      // Future: add Unix/macOS specific handling (e.g. sh -c) if needed.
    }

    // Executables like `"C:\path\to\file.exe" --arg1` are passed through.
    return trimmed;
  }
}

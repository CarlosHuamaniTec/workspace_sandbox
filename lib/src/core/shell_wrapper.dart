import 'dart:io';

/// Utility class for handling shell command wrapping across platforms.
///
/// Provides cross-platform abstraction for executing shell commands with
/// platform-specific shells (cmd.exe on Windows, /bin/sh on Unix).
class ShellWrapper {
  /// Wraps a raw command string into arguments for the system shell.
  ///
  /// On Windows, uses `cmd.exe /S /C "command"` to properly handle:
  /// - Spaces in file paths
  /// - Special characters
  /// - Quote escaping
  ///
  /// On Unix (Linux/macOS), uses `/bin/sh -c "command"`.
  ///
  /// Returns a list of arguments suitable for [Process.start].
  ///
  /// Example:
  /// ```
  /// final args = ShellWrapper.wrap('echo "Hello World" | grep Hello');
  /// // Windows: ['cmd.exe', '/S', '/C', 'echo "Hello World" | grep Hello']
  /// // Unix:    ['/bin/sh', '-c', 'echo "Hello World" | grep Hello']
  /// ```
  static List<String> wrap(String commandLine) {
    if (Platform.isWindows) {
      // /S: Modifies quote handling for proper escaping
      // /C: Execute command and terminate
      return ['cmd.exe', '/S', '/C', commandLine];
    } else {
      return ['/bin/sh', '-c', commandLine];
    }
  }

  /// Returns the default shell executable for the current platform.
  ///
  /// - Windows: `cmd.exe`
  /// - Linux/macOS: `/bin/sh`
  ///
  /// Example:
  /// ```
  /// print(ShellWrapper.defaultShell); // 'cmd.exe' on Windows
  /// ```
  static String get defaultShell {
    if (Platform.isWindows) return 'cmd.exe';
    return '/bin/sh';
  }
}

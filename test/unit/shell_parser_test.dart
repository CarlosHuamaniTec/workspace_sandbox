import 'dart:io';

import 'package:test/test.dart';
import 'package:workspace_sandbox/src/util/shell_parser.dart';

void main() {
  group('ShellParser.prepareCommand', () {
    test('throws on empty command', () {
      expect(
        () => ShellParser.prepareCommand('   '),
        throwsA(isA<Exception>()),
      );
    });

    test('returns trimmed command unchanged on non-Windows', () {
      if (Platform.isWindows) return; // skip on Windows

      final cmd = '  echo hello  ';
      final result = ShellParser.prepareCommand(cmd);
      expect(result, 'echo hello');
    });

    test('wraps Windows built-in commands with cmd.exe', () {
      if (!Platform.isWindows) return; // skip on non-Windows

      final cmd = 'echo hello';
      final result = ShellParser.prepareCommand(cmd);
      expect(
        result,
        'cmd.exe /s /c "echo hello"',
      );
    });

    test('wraps Windows commands containing pipes or redirects', () {
      if (!Platform.isWindows) return;

      final cmd = 'echo a | find "a"';
      final result = ShellParser.prepareCommand(cmd);
      expect(
        result,
        'cmd.exe /s /c "echo a | find "a""',
      );
    });

    test('does not wrap already wrapped cmd.exe commands', () {
      if (!Platform.isWindows) return;

      final cmd = 'cmd.exe /c echo hello';
      final result = ShellParser.prepareCommand(cmd);
      expect(result, cmd);
    });
  });
}

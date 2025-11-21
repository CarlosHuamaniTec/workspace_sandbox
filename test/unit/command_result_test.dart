import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace.dart';

void main() {
  group('CommandResult', () {
    test('isSuccess is true only when exitCode is zero', () {
      final ok = CommandResult(
        exitCode: 0,
        stdout: 'ok',
        stderr: '',
        duration: Duration(milliseconds: 10),
      );
      final fail = CommandResult(
        exitCode: 1,
        stdout: '',
        stderr: 'error',
        duration: Duration.zero,
      );

      expect(ok.isSuccess, isTrue);
      expect(fail.isSuccess, isFalse);
    });

    test('toString includes exitCode and duration', () {
      final res = CommandResult(
        exitCode: 2,
        stdout: '',
        stderr: '',
        duration: const Duration(milliseconds: 123),
      );

      final s = res.toString();
      expect(s, contains('exitCode: 2'));
      expect(s, contains('123ms'));
    });
  });
}

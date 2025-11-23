import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() {
  group('CommandResult Model', () {
    test('isSuccess logic', () {
      final success = CommandResult(
        exitCode: 0,
        stdout: '',
        stderr: '',
        duration: Duration.zero,
      );
      final failure = CommandResult(
        exitCode: 1,
        stdout: '',
        stderr: '',
        duration: Duration.zero,
      );

      expect(success.isSuccess, isTrue);
      expect(failure.isSuccess, isFalse);
    });

    test('ToString formatting', () async {
      final res = CommandResult(
        exitCode: 127,
        stdout: 'output',
        stderr: 'error msg',
        duration: const Duration(milliseconds: 500),
      );

      final log = res.toString();
      expect(log, contains('exitCode: 127'));
      expect(log, contains('500ms'));
    });

    test('Should handle empty outputs', () {
      final res = CommandResult(
          exitCode: 0, stdout: '', stderr: '', duration: Duration.zero);
      expect(res.stdout, isEmpty);
      expect(res.stderr, isEmpty);
    });
  });
}

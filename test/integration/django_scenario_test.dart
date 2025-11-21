import 'dart:async';
import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Real World Scenario: Django Backend Lifecycle', () {
    late Workspace ws;
    late Directory projectDir;
    late String fakePythonPath;
    late String fakeDjangoPath;

    setUp(() async {
      projectDir = await Directory.systemTemp.createTemp('django_test_');
      ws = Workspace.host(projectDir.path);

      final exeExt = Platform.isWindows ? '.exe' : '';
      fakePythonPath = p.join(projectDir.path, 'python$exeExt');
      fakeDjangoPath = p.join(projectDir.path, 'django-admin$exeExt');

      // --- MOCK PYTHON ---
      final pythonSource = p.join(projectDir.path, 'mock_python.dart');
      await File(pythonSource).writeAsString(r'''
        import 'dart:io';
        import 'dart:async';
        void main(List<String> args) async {
          if (args.isEmpty) return;
          if (args.contains('migrate')) {
             print("Running migrations... OK");
             exit(0);
          }
          if (args.contains('runserver')) {
             print("Starting development server at http://127.0.0.1:8000/");
             int i = 0;
             while(true) {
               stdout.writeln("GET /api/v1/users/ 200");
               await stdout.flush(); 
               await Future.delayed(Duration(seconds: 1));
               i++;
             }
          }
          exit(1);
        }
      ''');

      // --- MOCK DJANGO ---
      final djangoSource = p.join(projectDir.path, 'mock_django.dart');
      await File(djangoSource).writeAsString(r'''
        import 'dart:io';
        void main(List<String> args) {
          if (args.contains('startproject')) {
            final name = args.last;
            Directory(name).createSync(recursive: true);
            File('$name/manage.py').createSync(recursive: true);
            print("Created project: " + name);
            exit(0);
          }
          exit(1);
        }
      ''');

      // Compile Mocks
      await Process.run(Platform.executable,
          ['compile', 'exe', pythonSource, '-o', fakePythonPath]);
      await Process.run(Platform.executable,
          ['compile', 'exe', djangoSource, '-o', fakeDjangoPath]);
    });

    tearDown(() async {
      try {
        await projectDir.delete(recursive: true);
      } catch (_) {}
    });

    test('Full Lifecycle', () async {
      // 1. Create Project
      // IMPORTANT: We quote the paths explicitly to prevent whitespace issues
      final createCmd = '"$fakeDjangoPath" startproject my_backend';
      final res1 = await ws.run(createCmd);
      expect(res1.exitCode, 0, reason: "Startproject failed: ${res1.stderr}");

      // 2. Migrate
      final projectWs = Workspace.host(p.join(projectDir.path, 'my_backend'));
      final migrateCmd = '"$fakePythonPath" manage.py migrate';
      final res2 = await projectWs.run(migrateCmd);
      expect(res2.exitCode, 0, reason: "Migrate failed: ${res2.stderr}");

      // 3. Runserver (Streaming)
      final runCmd = '"$fakePythonPath" manage.py runserver';
      final proc = await projectWs.start(runCmd);

      final completer = Completer<void>();
      proc.stdout.listen((line) {
        if (line.contains('Starting development server') &&
            !completer.isCompleted) {
          completer.complete();
        }
      });

      try {
        await completer.future.timeout(Duration(seconds: 10));
      } catch (e) {
        proc.kill();
        fail("Timeout waiting for server start");
      }

      proc.kill();
      await proc.exitCode;
    });
  });
}

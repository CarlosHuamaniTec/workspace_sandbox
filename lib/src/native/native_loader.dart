import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;

class NativeLoader {
  static DynamicLibrary? _loadedLibrary;

  static DynamicLibrary load() {
    if (_loadedLibrary != null) return _loadedLibrary!;

    final filename = _libraryFilename();
    final arch = _architecture();

    final candidatePaths = <String>[
      // 0. Direct package-relative bin layout (works when running from package root)
      p.join(Directory.current.path, 'native', 'bin', _osFolderName(), arch,
          filename),

      // 1. Published package layout via _packageRelative (may be null)
      if (_packageRelative([
            'native',
            'bin',
            _osFolderName(),
            arch,
            filename,
          ]) !=
          null)
        _packageRelative([
          'native',
          'bin',
          _osFolderName(),
          arch,
          filename,
        ])!,

      // 2. Monorepo / local builds
      ..._buildFolderCandidates(filename),
    ];

    for (final path in candidatePaths) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          _loadedLibrary = DynamicLibrary.open(file.path);
          return _loadedLibrary!;
        } catch (_) {
          // Try next candidate
        }
      }
    }

    throw Exception(
      'Failed to locate native workspace_core library.\n'
      'Searched for $filename in:\n'
      '${candidatePaths.map((p) => '  - $p').join('\n')}\n'
      '\n'
      'If you are developing from source, make sure you have built the '
      'native library using CMake for your platform.\n',
    );
  }

  static String _libraryFilename() {
    if (Platform.isWindows) {
      return 'workspace_core.dll';
    } else if (Platform.isLinux) {
      return 'libworkspace_core.so';
    } else if (Platform.isMacOS) {
      return 'libworkspace_core.dylib';
    }
    throw UnsupportedError('Unsupported platform for workspace_core.');
  }

  static String _osFolderName() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }

  static String _architecture() {
    // For now we only ship x64 builds. This can be extended to arm64, etc.
    return 'x64';
  }

  /// Resolves a path relative to the package root.
  ///
  /// Uses [Platform.script] as an anchor and walks up until it finds
  /// the `lib/` folder of this package, then joins [segments].
  static String? _packageRelative(List<String> segments) {
    // Platform.script points to something inside the consuming package or
    // application; we need to walk up until we find this package's root.
    var dir = File(Platform.script.toFilePath()).parent;

    // Limit to a small depth to avoid scanning the whole filesystem.
    for (var i = 0; i < 10; i++) {
      final libDir = Directory(p.join(dir.path, 'lib'));
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));

      if (libDir.existsSync() && pubspec.existsSync()) {
        // Assume this is the package root.
        return p.joinAll([dir.path, ...segments]);
      }

      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  static List<String> _buildFolderCandidates(String filename) {
    final isWindows = Platform.isWindows;
    final buildFolder = isWindows ? 'build-windows' : 'build-linux';

    var dir = Directory.current;
    final candidates = <String>[];

    for (var i = 0; i < 10; i++) {
      candidates.addAll([
        // New segregated native build layout.
        p.join(dir.path, 'native', buildFolder, 'Release', filename),
        p.join(dir.path, 'native', buildFolder, filename),

        // Monorepo support: <root>/packages/workspace/native/...
        p.join(
          dir.path,
          'packages',
          'workspace',
          'native',
          buildFolder,
          'Release',
          filename,
        ),
        p.join(
          dir.path,
          'packages',
          'workspace',
          'native',
          buildFolder,
          filename,
        ),

        // Legacy build folder fallback.
        p.join(dir.path, 'native', 'build', 'Release', filename),
        p.join(dir.path, 'native', 'build', filename),
      ]);

      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    return candidates;
  }
}

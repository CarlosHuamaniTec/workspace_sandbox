import 'dart:io';
import 'package:path/path.dart' as p;

/// Low-level file system utilities for workspace operations.
///
/// Provides cross-platform implementations of common file operations
/// like tree visualization, grep search, and glob pattern matching.
class FileSystemHelpers {
  /// Generates a visual tree representation of a directory structure.
  ///
  /// Uses a flattened traversal strategy for OS consistency. Hidden files
  /// (starting with '.') are automatically excluded.
  ///
  /// Parameters:
  /// - [rootPath]: Absolute path to the directory to visualize
  /// - [maxDepth]: Maximum directory depth to traverse (default: 5)
  ///
  /// Returns a formatted tree string with box-drawing characters:
  /// ```
  /// project
  /// ├── src
  /// │   └── main.dart
  /// └── README.md
  /// ```
  ///
  /// Example:
  /// ```
  /// final tree = await FileSystemHelpers.tree('/path/to/project', maxDepth: 3);
  /// print(tree);
  /// ```
  static Future<String> tree(String rootPath, {int maxDepth = 5}) async {
    final dir = Directory(rootPath);
    if (!await dir.exists()) return '';

    final buffer = StringBuffer();
    buffer.writeln(p.basename(rootPath));

    List<FileSystemEntity> entities;
    try {
      await Future.delayed(const Duration(milliseconds: 10));
      entities = await dir.list(recursive: true, followLinks: false).toList();
    } catch (_) {
      return buffer.toString();
    }

    final paths = <String>[];
    for (var entity in entities) {
      final relative = p.relative(entity.path, from: rootPath);
      final parts = p.split(relative);
      if (parts.length > maxDepth) continue;
      if (parts.any((part) => part.startsWith('.'))) continue;
      paths.add(relative);
    }

    paths.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (paths.isEmpty) return buffer.toString();

    final openLevels = <int, bool>{};

    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      final parts = p.split(path);
      final level = parts.length - 1;
      final name = parts.last;

      bool isLast = true;
      if (i + 1 < paths.length) {
        final nextPath = paths[i + 1];
        final nextParts = p.split(nextPath);
        if (nextParts.length > level) {
          final currentParent =
              level == 0 ? '' : p.joinAll(parts.sublist(0, level));
          final nextParent =
              level == 0 ? '' : p.joinAll(nextParts.sublist(0, level));
          if (currentParent == nextParent) isLast = false;
        }
      }

      openLevels[level] = !isLast;

      var prefix = '';
      for (var k = 0; k < level; k++) {
        prefix += (openLevels[k] ?? false) ? '│   ' : '    ';
      }

      buffer.writeln('$prefix${isLast ? '└── ' : '├── '}$name');
    }

    return buffer.toString();
  }

  /// Searches for text patterns in files within a directory.
  ///
  /// Automatically skips binary files (images, executables, archives).
  /// Limits results to 500 matches to prevent memory exhaustion.
  ///
  /// Parameters:
  /// - [rootPath]: Absolute path to search directory
  /// - [pattern]: Text pattern to search for
  /// - [recursive]: Whether to search subdirectories (default: true)
  /// - [caseSensitive]: Whether to match case (default: true)
  ///
  /// Returns formatted results with file paths and line numbers:
  /// ```
  /// src/main.dart:42: print('Hello World');
  /// lib/util.dart:15: // Hello comment
  /// ```
  ///
  /// Example:
  /// ```
  /// final results = await FileSystemHelpers.grep(
  ///   '/path/to/project',
  ///   'TODO',
  ///   caseSensitive: false,
  /// );
  /// ```
  static Future<String> grep(String rootPath, String pattern,
      {bool recursive = true, bool caseSensitive = true}) async {
    final results = <String>[];
    final dir = Directory(rootPath);
    if (!await dir.exists()) return '';

    Stream<FileSystemEntity> stream =
        dir.list(recursive: recursive, followLinks: false);

    try {
      await for (final entity in stream) {
        if (entity is File) {
          const binaryExts = {
            '.png',
            '.jpg',
            '.jpeg',
            '.gif',
            '.bmp',
            '.exe',
            '.dll',
            '.so',
            '.dylib',
            '.bin',
            '.zip',
            '.tar',
            '.gz',
            '.pdf',
            '.ico'
          };
          if (binaryExts.contains(p.extension(entity.path).toLowerCase())) {
            continue;
          }

          try {
            final lines = await entity.readAsLines();
            for (var i = 0; i < lines.length; i++) {
              final line = lines[i];
              final match = caseSensitive
                  ? line.contains(pattern)
                  : line.toLowerCase().contains(pattern.toLowerCase());
              if (match) {
                final relPath = p.relative(entity.path, from: rootPath);
                final trimmed = line.trim();
                final preview = trimmed.length > 100
                    ? '${trimmed.substring(0, 100)}...'
                    : trimmed;
                results.add('$relPath:${i + 1}: $preview');

                if (results.length > 500) {
                  results.add('...');
                  return results.join('\n');
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    return results.join('\n');
  }

  /// Finds files matching a glob pattern.
  ///
  /// Supports wildcards:
  /// - `*` matches any sequence of characters
  /// - `?` matches a single character
  ///
  /// Matching is case-insensitive.
  ///
  /// Example:
  /// ```
  /// final dartFiles = await FileSystemHelpers.find('/project', '*.dart');
  /// final testFiles = await FileSystemHelpers.find('/project', 'test_*.dart');
  /// ```
  ///
  /// Returns a list of relative file paths matching the pattern.
  static Future<List<String>> find(String rootPath, String pattern) async {
    final results = <String>[];
    final dir = Directory(rootPath);
    if (!await dir.exists()) return [];

    final regex = RegExp(
        '^${RegExp.escape(pattern).replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$',
        caseSensitive: false);

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (regex.hasMatch(p.basename(entity.path))) {
        results.add(p.relative(entity.path, from: rootPath));
      }
    }

    return results;
  }

  /// Copies a file or directory recursively.
  ///
  /// If [srcPath] is a file, copies it to [destPath].
  /// If [srcPath] is a directory, recursively copies all contents.
  ///
  /// Throws [FileSystemException] if the source doesn't exist.
  static Future<void> copy(String srcPath, String destPath) async {
    final type = await FileSystemEntity.type(srcPath);

    if (type == FileSystemEntityType.file) {
      await File(srcPath).copy(destPath);
    } else if (type == FileSystemEntityType.directory) {
      await Directory(destPath).create(recursive: true);
      await for (final entity in Directory(srcPath).list(recursive: false)) {
        await copy(entity.path, p.join(destPath, p.basename(entity.path)));
      }
    }
  }

  /// Moves a file or directory to a new location.
  ///
  /// Automatically creates parent directories for the destination.
  ///
  /// Throws [FileSystemException] if the source doesn't exist or the
  /// destination is invalid.
  static Future<void> move(String srcPath, String destPath) async {
    final type = await FileSystemEntity.type(srcPath);
    await Directory(p.dirname(destPath)).create(recursive: true);

    if (type == FileSystemEntityType.file) {
      await File(srcPath).rename(destPath);
    } else if (type == FileSystemEntityType.directory) {
      await Directory(srcPath).rename(destPath);
    }
  }

  /// Deletes a file or directory.
  ///
  /// If the path is a directory, deletes it recursively.
  ///
  /// Throws [FileSystemException] if the path doesn't exist.
  static Future<void> delete(String path) async {
    final type = await FileSystemEntity.type(path);

    if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    }
  }
}

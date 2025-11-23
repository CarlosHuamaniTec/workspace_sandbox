import 'dart:io';
import 'package:path/path.dart' as p;

/// Security utility for validating and resolving file paths within a workspace.
///
/// Prevents path traversal attacks by ensuring all resolved paths stay within
/// the workspace root directory.
class PathSecurity {
  /// The absolute path to the workspace root directory.
  final String rootPath;

  /// Creates a path security validator for the given workspace root.
  ///
  /// Example:
  /// ```
  /// final security = PathSecurity('/tmp/workspace');
  /// final safePath = security.resolve('config.json'); // OK
  /// security.resolve('../../../etc/passwd'); // Throws SecurityException
  /// ```
  PathSecurity(this.rootPath);

  /// Resolves a relative path to an absolute path within the workspace.
  ///
  /// Validates that the resolved path does not escape the workspace root
  /// directory using path traversal sequences like `..`.
  ///
  /// Parameters:
  /// - [relativePath]: A relative path within the workspace
  ///
  /// Returns the absolute, normalized path within the workspace.
  ///
  /// Throws [FileSystemException] if:
  /// - The path contains `..` segments that escape the root
  /// - An absolute path is provided that doesn't start with [rootPath]
  ///
  /// Example:
  /// ```
  /// final security = PathSecurity('/workspace');
  /// security.resolve('src/main.dart'); // -> /workspace/src/main.dart
  /// security.resolve('../secrets'); // -> throws FileSystemException
  /// ```
  String resolve(String relativePath) {
    final cleanRel = p.normalize(relativePath);

    if (cleanRel.startsWith('..') ||
        (p.isAbsolute(relativePath) && !relativePath.startsWith(rootPath))) {
      throw FileSystemException(
          'Security Error: Path attempts to escape workspace root.',
          relativePath);
    }

    return p.join(rootPath, cleanRel);
  }
}

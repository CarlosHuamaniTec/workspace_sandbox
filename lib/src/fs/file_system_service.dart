import 'dart:io';
import '../core/path_security.dart';
import '../util/file_system_helpers.dart';

/// High-level file system service with path security validation.
///
/// All operations are scoped to the workspace root directory and prevent
/// path traversal attacks by validating paths before execution.
class FileSystemService {
  final PathSecurity _security;

  /// Creates a file system service for the given workspace root.
  ///
  /// All file operations will be restricted to paths within [rootPath].
  FileSystemService(String rootPath) : _security = PathSecurity(rootPath);

  /// The absolute path to the workspace root directory.
  String get rootPath => _security.rootPath;

  /// Writes text content to a file.
  ///
  /// Creates parent directories automatically if they don't exist.
  ///
  /// Throws [SecurityException] if [relativePath] attempts to escape the workspace.
  ///
  /// Example:
  /// ```
  /// await fs.writeFile('config.json', '{"debug": true}');
  /// ```
  Future<File> writeFile(String relativePath, String content) async {
    final file = File(_security.resolve(relativePath));
    await file.parent.create(recursive: true);
    return file.writeAsString(content);
  }

  /// Reads text content from a file.
  ///
  /// Throws [FileSystemException] if the file doesn't exist.
  /// Throws [SecurityException] if [relativePath] attempts to escape the workspace.
  Future<String> readFile(String relativePath) async {
    final file = File(_security.resolve(relativePath));
    if (!await file.exists()) {
      throw FileSystemException('File not found', relativePath);
    }
    return file.readAsString();
  }

  /// Writes binary data to a file.
  ///
  /// Creates parent directories automatically if they don't exist.
  ///
  /// Example:
  /// ```
  /// final imageBytes = await http.readBytes('https://example.com/image.png');
  /// await fs.writeBytes('assets/logo.png', imageBytes);
  /// ```
  Future<File> writeBytes(String relativePath, List<int> bytes) async {
    final file = File(_security.resolve(relativePath));
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes);
  }

  /// Reads binary data from a file.
  ///
  /// Throws [FileSystemException] if the file doesn't exist.
  Future<List<int>> readBytes(String relativePath) async {
    final file = File(_security.resolve(relativePath));
    if (!await file.exists()) {
      throw FileSystemException('File not found', relativePath);
    }
    return file.readAsBytes();
  }

  /// Creates a directory.
  ///
  /// Creates parent directories recursively if needed.
  ///
  /// Example:
  /// ```
  /// await fs.createDir('src/utils/helpers');
  /// ```
  Future<Directory> createDir(String relativePath) async {
    final dir = Directory(_security.resolve(relativePath));
    return dir.create(recursive: true);
  }

  /// Checks if a file or directory exists.
  ///
  /// Returns true if the path exists as either a file or directory.
  Future<bool> exists(String relativePath) async {
    final path = _security.resolve(relativePath);
    return await File(path).exists() || await Directory(path).exists();
  }

  /// Generates a visual tree of the workspace directory structure.
  ///
  /// See [FileSystemHelpers.tree] for output format details.
  Future<String> tree({int? maxDepth}) async {
    final depth = maxDepth ?? 5;
    return FileSystemHelpers.tree(_security.rootPath, maxDepth: depth);
  }

  /// Searches for text patterns in workspace files.
  ///
  /// See [FileSystemHelpers.grep] for details on pattern matching.
  Future<String> grep(String pattern,
      {bool recursive = true, bool caseSensitive = true}) async {
    return FileSystemHelpers.grep(_security.rootPath, pattern,
        recursive: recursive, caseSensitive: caseSensitive);
  }

  /// Finds files matching a glob pattern.
  ///
  /// See [FileSystemHelpers.find] for pattern syntax.
  Future<List<String>> find(String pattern) async {
    return FileSystemHelpers.find(_security.rootPath, pattern);
  }

  /// Copies a file or directory.
  ///
  /// Both paths are relative to the workspace root.
  ///
  /// Example:
  /// ```
  /// await fs.copy('template.txt', 'output/file.txt');
  /// ```
  Future<void> copy(String srcRel, String destRel) async {
    await FileSystemHelpers.copy(
        _security.resolve(srcRel), _security.resolve(destRel));
  }

  /// Moves a file or directory.
  ///
  /// Both paths are relative to the workspace root.
  ///
  /// Example:
  /// ```
  /// await fs.move('old_name.txt', 'new_name.txt');
  /// ```
  Future<void> move(String srcRel, String destRel) async {
    await FileSystemHelpers.move(
        _security.resolve(srcRel), _security.resolve(destRel));
  }

  /// Deletes a file or directory.
  ///
  /// If the path is a directory, deletes it recursively.
  ///
  /// Throws [FileSystemException] if the path doesn't exist.
  Future<void> delete(String relativePath) async {
    await FileSystemHelpers.delete(_security.resolve(relativePath));
  }
}

# workspace_sandbox

[![pub package](https://img.shields.io/pub/v/workspace_sandbox.svg)](https://pub.dev/packages/workspace_sandbox)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A cross-platform workspace abstraction for running shell commands in a contained directory, with streaming stdout/stderr, timeouts and optional native sandboxing (AppContainer on Windows, bubblewrap on Linux).

This package is designed for **local AI agents**, **automation tools** and **CLIs** that need to execute arbitrary commands while keeping them scoped to a workspace root with strong isolation guarantees.

---

## 🎯 Features

- **Isolated workspace roots** – Host-based or ephemeral temporary workspaces
- **Streaming output** – Access stdout and stderr as Dart `Stream<String>`
- **Timeouts & cancellation** – Kill long-running processes automatically
- **Native process management** – Uses `dart:ffi` for direct OS integration (Windows, Linux x64)
- **Optional sandboxing**:
  - **Windows**: Runs processes inside an AppContainer with restricted tokens
  - **Linux**: Wraps processes in `bwrap` (bubblewrap) with filesystem isolation
- **Simple, tested API** – Works in both Dart CLI and Flutter applications
- **File helpers** – Read, write, delete files scoped to the workspace root

---

## 📦 Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  workspace_sandbox: ^0.1.0
```

Then run:

```bash
dart pub get
```

---

## 🚀 Quick Start

### Secure, temporary workspace

Create an ephemeral workspace in the system temp directory:

```dart
import 'package:workspace_sandbox/workspace.dart';

Future<void> main() async {
  // Secure, ephemeral workspace in the system temp directory
  final ws = Workspace.secure();

  // Write a file inside the workspace root
  await ws.writeFile('hello.txt', 'Hello from workspace!');

  // Run a simple command that reads the file
  final result = await ws.run(
    'cat hello.txt',
    options: const WorkspaceOptions(
      timeout: Duration(seconds: 5),
    ),
  );

  print('exitCode: ${result.exitCode}');
  print('stdout: ${result.stdout}');
  print('stderr: ${result.stderr}');

  // Cleanup (deletes temp directory)
  await ws.dispose();
}
```

### Host workspace

Use an existing directory as the workspace root:

```dart
import 'package:workspace_sandbox/workspace.dart';

Future<void> main() async {
  final ws = Workspace.host('/path/to/project');

  final result = await ws.run('git status');

  if (result.isSuccess) {
    print(result.stdout);
  } else {
    print('Command failed: ${result.stderr}');
  }

  await ws.dispose();
}
```

### Streaming output for long-running commands

```dart
import 'package:workspace_sandbox/workspace.dart';

Future<void> main() async {
  final ws = Workspace.secure();

  final process = await ws.start('npm install');

  // Listen to stdout in real-time
  process.stdout.listen((line) {
    print('[OUT] $line');
  });

  // Listen to stderr in real-time
  process.stderr.listen((line) {
    print('[ERR] $line');
  });

  // Wait for process to complete
  final exitCode = await process.exitCode;
  print('Process exited with code: $exitCode');

  await ws.dispose();
}
```

---

## 📚 API Overview

### `Workspace`

The main entry point for creating and managing workspaces.

#### Static constructors

- **`Workspace.secure({ String? id, WorkspaceOptions? options })`**  
  Creates a temporary, ephemeral workspace rooted in the system temp directory. Files and directories are automatically deleted when `dispose()` is called.

- **`Workspace.host(String path, { String? id, WorkspaceOptions? options })`**  
  Uses or creates a host directory at `path` as the workspace root. Files persist after `dispose()`.

#### Methods

- **`Future<CommandResult> run(String commandLine, { WorkspaceOptions? options })`**  
  Runs a command to completion and returns a buffered `CommandResult` with stdout, stderr, exitCode and duration.

- **`Future<WorkspaceProcess> start(String commandLine, { WorkspaceOptions? options })`**  
  Starts a long-running process and returns a `WorkspaceProcess` with `stdout`, `stderr` streams and an `exitCode` future for real-time output.

- **File helpers** (all paths are relative to workspace root):
  - `Future<void> writeFile(String relativePath, String content)`
  - `Future<String> readFile(String relativePath)`
  - `Future<bool> exists(String relativePath)`
  - `Future<void> createDir(String relativePath)`
  - `Future<void> delete(String relativePath)`

- **`Future<void> dispose()`**  
  Cleans up resources. For ephemeral workspaces, deletes the temp directory.

---

### `WorkspaceOptions`

Configuration object for customizing command execution behavior.

**Fields:**

- **`Duration? timeout`** – Optional timeout; process is killed after this duration
- **`Map<String, String>? env`** – Additional environment variables for the process
- **`bool includeParentEnv`** – Whether to inherit the parent process environment (default: `true`)
- **`String? workingDirectoryOverride`** – Custom working directory inside the workspace (default: workspace root)
- **`bool sandbox`** – Whether to request native OS-level sandboxing (default: `false`)

**Example:**

```dart
final result = await ws.run(
  'python script.py',
  options: WorkspaceOptions(
    timeout: Duration(minutes: 5),
    env: {'PYTHONPATH': '/custom/path'},
    sandbox: true,
  ),
);
```

---

### `CommandResult`

The result of a completed command (returned by `Workspace.run()`).

**Fields:**

- **`int exitCode`** – Process exit code (0 typically means success)
- **`String stdout`** – Captured stdout text
- **`String stderr`** – Captured stderr text
- **`Duration duration`** – Total execution time
- **`bool isCancelled`** – `true` if the process was killed due to timeout or explicit cancellation

**Convenience getters:**

- **`bool get isSuccess`** – Returns `exitCode == 0`
- **`bool get isFailure`** – Returns `exitCode != 0`

---

### `WorkspaceProcess`

A handle to a running process (returned by `Workspace.start()`).

**Fields:**

- **`Stream<String> stdout`** – Real-time stdout stream (line-by-line)
- **`Stream<String> stderr`** – Real-time stderr stream (line-by-line)
- **`Future<int> exitCode`** – Completes when the process terminates with the exit code

**Methods:**

- **`Future<void> kill()`** – Terminates the process immediately

---

## 🔒 Sandbox Behavior

When `WorkspaceOptions.sandbox` is set to `true` (or when using `Workspace.secure()`, which enforces sandboxing internally), the native core attempts to isolate the process at the OS level:

### Windows

The process is launched inside a **Windows AppContainer** using a restricted token derived from the current process. This provides:

- Limited filesystem access
- No network access by default
- Isolated from the parent process's privileges

### Linux (x64)

The process is launched under **`bwrap` (bubblewrap)** with the following isolation:

- **New namespaces** (`--unshare-all`, `--die-with-parent`)
- **Read-only bindings** for `/`, `/usr`, `/bin`
- **Real `/dev` and `/proc`** for basic functionality
- **`tmpfs` at `/tmp`** for temporary writes
- **Workspace root bind-mounted** and set as the working directory (for `Workspace.host`)

### Fallback

If sandboxing is not supported (e.g., `bwrap` not installed on Linux), the core automatically falls back to a non-sandboxed execution model for that command.

> ⚠️ **Security Note**: Always validate and constrain which commands you allow your agents to run on top of this API. Sandboxing provides defense-in-depth but is not a replacement for proper input validation and command allowlisting.

---

## 🖥️ Platform Support

| Platform | Architecture | Status           |
|---------|--------------|------------------|
| Windows | x64          | ✅ Supported     |
| Linux   | x64          | ✅ Supported     |
| macOS   | –            | ❌ Not supported yet |

Support for additional platforms (including macOS and ARM architectures) may be added in future versions.

---

## ⚠️ Limitations

- **Prebuilt binaries only for Windows x64 and Linux x64**  
  Other platforms are not currently supported.

- **No interactive TTY support**  
  Commands that require interactive input (e.g., text editors, interactive shells) are not supported out-of-the-box.

- **Linux sandboxing requires bubblewrap**  
  The `bwrap` binary must be installed on Linux for sandboxing to work. Install it via:
  ```bash
  # Ubuntu/Debian
  sudo apt install bubblewrap
  
  # Fedora/RHEL
  sudo dnf install bubblewrap
  
  # Arch
  sudo pacman -S bubblewrap
  ```

---

## 🤝 Contributing

Contributions, bug reports and feature requests are welcome!

- **File issues**: [GitHub Issues](https://github.com/deskhand-software/workspace_sandbox/issues)
- **Submit PRs**: Please ensure your changes pass the following checks before submitting:

```bash
dart format lib test
dart analyze
dart test
```

Also ensure that the native library still builds successfully on both Windows and Linux.

### Building the native library

If you need to rebuild the native FFI library:

**Linux:**
```bash
cd native
mkdir -p build-linux && cd build-linux
cmake ..
cmake --build . --config Release
cp libworkspace_core.so ../bin/linux/x64/
```

**Windows:**
```powershell
cd native
New-Item -ItemType Directory -Path build-windows -Force
cd build-windows
cmake .. -A x64
cmake --build . --config Release
Copy-Item .\Release\workspace_core.dll ..\bin\windows\x64\
```

---

## 📄 License

This project is licensed under the **Apache-2.0 License**.  
See the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Built with [dart:ffi](https://dart.dev/guides/libraries/c-interop) for native interop
- Sandboxing powered by Windows AppContainer and Linux bubblewrap
- Designed for AI agents and automation workflows

---

## 📞 Support

- **Documentation**: [pub.dev/packages/workspace_sandbox](https://pub.dev/packages/workspace_sandbox)
- **Issues**: [GitHub Issues](https://github.com/deskhand-software/workspace_sandbox/issues)
- **Organization**: [DeskHand Software](https://deskhand.dev)

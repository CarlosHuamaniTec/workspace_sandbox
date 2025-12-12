# workspace_sandbox

[![pub package](https://img.shields.io/pub/v/workspace_sandbox.svg)](https://pub.dev/packages/workspace_sandbox)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A cross-platform workspace abstraction for running shell commands in isolated directories with native sandboxing, network control, and real-time process streaming.

Designed for **AI agents**, **automation tools**, and **build systems** that need to execute arbitrary commands with strong isolation guarantees and file system observability.

---

## Features

- **Isolated workspaces** – Ephemeral or persistent directory roots with automatic cleanup
- **Native sandboxing** – Job Objects (Windows), Bubblewrap (Linux), Seatbelt (macOS)
- **Network control** – Block or allow network access per workspace
- **Streaming output** – Real-time stdout/stderr via Dart streams
- **Reactive events** – Monitor process lifecycle and output via `onEvent` stream
- **Timeout & cancellation** – Automatic process termination with configurable timeouts
- **File system helpers** – Tree visualization, recursive grep, glob search, binary I/O
- **Simple API** – Write commands as you would in a terminal, no complex process management

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  workspace_sandbox: ^0.1.6
```

Then run:

```bash
dart pub get
```

---

## Quick Start

### Basic Usage

```dart
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  final ws = Workspace.ephemeral();
  
  await ws.fs.writeFile('script.sh', 'echo "Hello World"');
  
  final result = await ws.exec('sh script.sh');
  print(result.stdout); // Hello World
  
  await ws.dispose();
}
```

### With Network Isolation

```dart
final ws = Workspace.ephemeral(
  options: const WorkspaceOptions(
    sandbox: true,
    allowNetwork: false, // Block all network access
  ),
);

// This will fail with network unreachable
await ws.exec('ping google.com');
```

### Streaming Long-Running Processes

```dart
final ws = Workspace.ephemeral();

final process = await ws.execStream('npm install');

process.stdout.listen((line) => print('[NPM] $line'));
process.stderr.listen((line) => print('[ERR] $line'));

final exitCode = await process.exitCode;
print('Installation complete: $exitCode');

await ws.dispose();
```

### Reactive Event Monitoring

```dart
final ws = Workspace.ephemeral();

// Listen to all workspace events
ws.onEvent.listen((event) {
  if (event is ProcessLifecycleEvent) {
    print('Process ${event.pid}: ${event.state}');
  } else if (event is ProcessOutputEvent) {
    print('[${event.isError ? "ERR" : "OUT"}] ${event.content}');
  }
});

await ws.exec('echo "Hello"');
await ws.dispose();
```

---

## API Reference

### Workspace

Primary interface for creating and managing isolated execution environments.

#### Constructors

**`Workspace.ephemeral({ String? id, WorkspaceOptions? options })`**

Creates an ephemeral workspace in the system temp directory with sandboxing enabled by default. Automatically deleted on `dispose()`.

**`Workspace.at(String path, { String? id, WorkspaceOptions? options })`**

Uses an existing directory as the workspace root. Files persist after `dispose()`. Sandboxing is optional.

#### Core Methods

**`Future<CommandResult> exec(Object command, { WorkspaceOptions? options })`**

Execute a command or binary to completion (String = shell, List<String> = binary). Returns buffered stdout, stderr, and exit code.

```dart
final result = await ws.exec('python script.py');
if (result.isSuccess) {
  print(result.stdout);
}

final result2 = await ws.exec(['git', 'status']);
```

**`Future<WorkspaceProcess> execStream(Object command, { WorkspaceOptions? options })`**

Start a streaming process (shell or binary). Returns a process handle for streaming output.

```dart
final proc = await ws.execStream('tail -f log.txt');
proc.stdout.listen(print);
```

### File System API (`ws.fs`)

All file and directory operations are accessed via `ws.fs`:

- `Future<File> writeFile(String path, String content)`
- `Future<String> readFile(String path)`
- `Future<File> writeBytes(String path, List<int> bytes)`
- `Future<List<int>> readBytes(String path)`
- `Future<bool> exists(String path)`
- `Future<Directory> createDir(String path)`
- `Future<void> delete(String path)`
- `Future<void> copy(String source, String dest)`
- `Future<void> move(String source, String dest)`
- `Future<String> tree({ int maxDepth = 5 })`
- `Future<String> grep(String pattern, { bool recursive = true })`
- `Future<List<String>> find(String pattern)`

---

### Example: Find all Dart files and print a directory tree

```dart
final ws = Workspace.ephemeral();

await ws.fs.writeFile('main.dart', '// Dart entry point');
await ws.fs.createDir('src');
await ws.fs.writeFile('src/lib.dart', '// Helper lib');

final files = await ws.fs.find('*.dart');
print('Found Dart files: $files');

print(await ws.fs.tree());

await ws.dispose();
```

---

### Event Stream

**`Stream<WorkspaceEvent> onEvent`**—Unified stream of all events happening in the workspace.

---

## Security & Sandboxing

**Windows (x64):** Processes run in Job Objects. Automatic child process cleanup and network proxy blocking.

**Linux (x64):** Sandboxing with Bubblewrap; kernel network namespace, host root read-only.

**macOS (x64/ARM64):** Sandboxing with Seatbelt; read-only host, workspace write and cache access.

---

## Platform Support

| Platform | Architecture | Sandboxing | Network Isolation |
|----------|-------------|------------|-------------------|
| Windows  | x64         | Job Objects | ENV proxy blocking |
| Linux    | x64         | Bubblewrap (bwrap) | Kernel-level (`--unshare-net`) |
| macOS    | x64/ARM64   | Seatbelt (sandbox-exec) | Process-level blocking |

---

## Requirements

### Linux

Bubblewrap required for sandboxing:

```bash
sudo apt install bubblewrap    # Ubuntu/Debian
sudo dnf install bubblewrap    # Fedora/RHEL
sudo pacman -S bubblewrap      # Arch
```

### Windows
No additional dependencies.

### macOS
No additional dependencies.

---

## Examples

See the `example/` directory for comprehensive usage demonstrations:
- `main.dart` – Quick-start basic usage
- `01_advanced_python_api.dart` – Python/Django build automation
- `02_security_audit.dart` – Security and isolation (blocked network/access)
- `03_git_workflow_at.dart` – Persistent workspace + git
- `04_data_processing_spawn.dart` – Long-running background processes, binary IO
- `05_interactive_repl.dart` – Real-time streaming output, Python REPL

Run any example:

```bash
dart run example/main.dart
```

---

## Building Native Binaries

The native launcher is written in Rust. See `native/` for build scripts.

---

## Contributing

Contributions are welcome!

```bash
dart format lib test example
dart analyze
dart test
```

Please ensure native launcher builds on all platforms.

[LICENSE: Apache-2.0](LICENSE)

---

## Links
- **Documentation:** https://pub.dev/packages/workspace_sandbox
- **Issues:** https://github.com/CarlosHuamaniTec/workspace_sandbox/issues

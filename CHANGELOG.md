# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.6] - 2025-12-12

### Changed
- Project ownership transferred to Carlos Huamani. Repository and issue tracker links have been updated accordingly.

---

## [0.1.5] - 2025-11-24

### BREAKING CHANGES

- **Unified API:** Replaced multiple execution methods (`run`, `exec`, `start`, `spawn`) with a single, ergonomic `exec(Object command)` and `execStream(Object command)` interface.
  - Shell commands are now run as `ws.exec('ls -la')`.
  - Direct (binary) execution is now `ws.exec(['git', 'status'])`.
  - All streaming/background process APIs use `execStream`.
- **Filesystem API Refactored:** All file/directory operations now accessed via `ws.fs.*` (e.g., `ws.fs.writeFile(...)`).
- **Removed:** Methods `run`, `exec`, `start`, `spawn`, `writeFile`, `readFile`, `createDir`, `tree`, etc, from `Workspace`. See README for migration.

### Fixed

- **Security/Bug:** Path traversal vulnerability in `PathSecurity.resolve` fixed (prevents `../../../etc`).
- **Type Safety:** `WorkspaceProcess` now always exposes the `pid` field. No more dynamic casting required.

### Changed

- Minimalist, intuitive developer experience. See new unified interface and usage in updated README and examples.
- All core examples and tests migrated to modern facade.
- Zero runtime API confusion. All parameters named, all operations discoverable via `Workspace` or `ws.fs`.
- **Dependencies:** Moved `http` package from `dependencies` to `dev_dependencies` (only used in tests).

### Added

- Expanded examples with all main combinations of the new API (shell, binary, streaming, persistent, ephemeral, filesystem, security).
- Pub score expected: 160/160.

### Migration Guide

- `ws.run(...)` ⟶ `ws.exec(...)`
- `ws.writeFile(...)` ⟶ `ws.fs.writeFile(...)`
- `ws.tree()` ⟶ `ws.fs.tree()`
- Etc. See README or run `dart doc workspace_sandbox`.

---

## [0.1.4] - 2025-11-23

### Fixed

- **Critical:** Fixed binary detection when used as pub dependency in Flutter/Dart projects
- Launcher now correctly resolves package location using `.dart_tool/package_config.json`
- Binary path resolution works seamlessly in all installation contexts (pub.dev, git, path)

### Changed

- Simplified binary detection to 3 essential strategies:
  1. Package cache via `package_config.json` (production installations)
  2. Development build (`native/target/release/`)
  3. Project bin directory (direct path dependencies)
- Removed redundant detection methods for cleaner error messages
- Enhanced error reporting with comprehensive searched paths list

### Technical Details

The launcher now parses `.dart_tool/package_config.json` to reliably locate the package root in pub cache, eliminating the "binary not found" error when installing from pub.dev.

---

## [0.1.3] - 2025-11-23
### Fixed

- **Critical:** Fix `.pubignore` excluding `lib/src/native/` directory (caused 80/160 pub points)

- Update README.md with correct platform support information

- Correct sandboxing documentation (Job Objects vs AppContainer on Windows)

- Update build instructions for Rust binaries

- Add reactive event system documentation

---

## [0.1.2] - 2025-11-23 

> **⚠️ WARNING:** This version has a packaging error that excludes `lib/src/native/` due to incorrect `.pubignore` configuration. The package cannot be analyzed correctly by pub.dev (80/160 points). **Please use 0.1.3 or later.**

**Complete Native Architecture Rewrite**
- Migrated from FFI + C++ to **pure Rust** standalone binary
- Native launcher now runs as separate process (`workspace_launcher` binary)
- Communication via serialized CLI arguments instead of FFI calls
- **Rationale:** Better cross-platform compatibility, easier maintenance, eliminated FFI marshalling overhead

**API Compatibility:** No breaking changes for Dart users. All public APIs remain identical.

### Added

**Event System & Reactive Logging**
- `Workspace.onEvent` stream for real-time workspace monitoring
- `ProcessLifecycleEvent`: Track process start/stop with PID and exit codes
- `ProcessOutputEvent`: Stream stdout/stderr chunks in real-time
- `WorkspaceEvent` base class with timestamp and workspace ID

**macOS Support**
- Full sandboxing via **Seatbelt** (sandbox-exec)
- Read-only host filesystem with workspace write access
- Network isolation control
- Binaries included: `bin/macos/x64/workspace_launcher`

**Enhanced Examples**
- `01_advanced_python_api.dart`: HTTP server with streaming logs
- `02_security_audit.dart`: Network isolation validation
- `03_git_workflow_at.dart`: Persistent workspace git operations
- `04_data_processing_spawn.dart`: Long-running background processes
- `05_interactive_repl.dart`: Real-time stdin/stdout interaction
- `example.dart`: Quick-start basic usage

### Changed

**Windows Sandboxing Overhaul**
- Replaced **AppContainer** with **Job Objects**
- Fixes Maven/Gradle cache detection issues (AppContainer broke user home paths)
- More reliable process group termination
- Network isolation via environment variable proxies

**Linux Sandboxing Improvements**
- **Root Passthrough** strategy: Mount entire host as read-only
- Selective tool cache exposure (`.m2`, `.gradle`, `.cargo`, `.pub-cache`)
- Fixed DNS resolution in sandboxed environments (handle `/run` symlinks)
- Improved compatibility with WSL2 and modern distributions

**Internal Refactoring**
- New modular Rust architecture:
  - `strategies/` directory with platform-specific isolation
  - `base.rs`: Core `IsolationStrategy` trait
  - `linux.rs`, `windows.rs`, `macos.rs`, `host.rs`: Platform implementations
- `LauncherService` now spawns native binary with `--id`, `--workspace`, `--sandbox`, `--no-net` flags
- `ShellWrapper` handles cross-platform shell invocation (`cmd.exe` vs `/bin/sh`)

**Documentation**
- Complete API documentation (160/160 Pana score)
- All public symbols documented with examples
- Rust code fully commented (Clippy pedantic compliant)

### Fixed

- **Windows:** Job Objects correctly handle child process termination
- **Linux:** Bubblewrap now mounts tool caches for Maven/Gradle/NPM
- **Cross-platform:** UTF-8 decoding with `allowMalformed: true` for non-Unicode output (Windows CP850)
- **Network isolation:** Actually enforced at OS level (not just heuristic blocking)
- **Process streams:** Broadcast controllers allow multiple listeners

### Security

**Enhanced Isolation**
- macOS Seatbelt profiles block unauthorized filesystem access
- Linux network namespaces provide kernel-level network blocking
- Windows Job Objects prevent privilege escalation
- All platforms enforce workspace root confinement

### Technical Details

**Native Binary Stack**
- Rust 1.83+ with Tokio async runtime
- Dependencies: `anyhow`, `clap`, `tokio`, `which`
- Cross-compilation support for all three platforms
- Binary sizes: ~800KB per platform

**Build System**
- `cargo build --release` for native binaries
- Prebuilt binaries included in `bin/{linux,windows,macos}/x64/`
- Source code in `native/src/` (Rust)
- No C++ dependencies

---

## [0.1.1] - 2025-11-22

### Added

**FileSystem Observability Helpers**
- `tree(maxDepth)`: Generate visual directory tree for LLM context windows
- `grep(pattern, recursive)`: Recursive text search with file:line output
- `find(pattern)`: Glob-style file pattern matching
- `readBytes()` / `writeBytes()`: Binary file I/O support
- `copy(source, dest)` / `move(source, dest)`: File management utilities

**Network Isolation Control**
- New `allowNetwork` flag in `WorkspaceOptions` (defaults to `true`)
- Linux: Native kernel-level network blocking via `--unshare-net` (Bubblewrap)
- Windows: Heuristic-based `SecurityGuard` blocks known network binaries (curl, wget, ssh, npm) before execution
- Detects and blocks Python socket usage and PowerShell network calls

**Enhanced Timeout & Cancellation**
- `isCancelled` flag in `CommandResult` reliably indicates timeout-triggered termination
- Improved native process cleanup on timeout (SIGKILL on Linux, TerminateProcess on Windows)
- Timeout now properly propagates cancellation state regardless of OS exit code quirks

**Expanded Examples**
- `01_basic_usage.dart`: Core workspace lifecycle demonstration
- `02_observability.dart`: File system inspection utilities showcase
- `03_network_isolation.dart`: Network blocking and allowing examples
- `04_streaming_output.dart`: Real-time process output handling
- `05_timeout_control.dart`: Timeout mechanism validation
- `06_host_vs_secure.dart`: Persistent vs ephemeral workspace comparison

### Changed

**Linux Sandboxing Improvements**
- Migrated to "Empty Root" strategy (`--tmpfs /`) for maximum isolation
- Added `/usr/local` mount for user-installed binaries (npm, node)
- Improved support for Merged-USR distributions (Fedora, Arch, modern Ubuntu)
- Added standard symlinks (`/bin` -> `/usr/bin`, `/lib` -> `/usr/lib`)

**API Refinements**
- `CommandResult` now exposes `isSuccess` and `isFailure` convenience getters
- Internal `command_line` variables renamed to `commandLine` for Dart convention compliance
- Improved error messages with platform-specific language support (Spanish Windows errors)

### Fixed

- Windows: Resolved native library linker errors and C++ signature mismatches
- Linux: Fixed NPM/Node.js detection in sandboxed environments (WSL2 compatibility)
- Cross-platform: `ShellParser` now handles case-insensitive command detection (e.g., `CuRl`, `PoWeRsHeLl`)
- Timeout mechanism now correctly reports cancellation state across all platforms
- Whitespace handling in shell command parsing (quotes, pipes, redirects)

### Security

- Enhanced static analysis in `SecurityGuard` for obfuscated network commands
- Improved detection of inline scripting language network usage (Python `urllib`, Node.js `require('net')`)
- Added comprehensive penetration testing suite (`pentest_test.dart`) validating:
  - Path traversal protection (Dart API and OS-level)
  - Symlink attack resistance (Linux)
  - Network exfiltration prevention (socket-level)
  - Resource exhaustion handling (fork bomb simulation)

---

## [0.1.0] - 2025-11-21

### Added

**Core Workspace API**
- `Workspace.secure()`: Creates ephemeral temporary workspaces with automatic cleanup and native sandboxing
- `Workspace.host(path)`: Uses existing directories as workspace roots
- `run()`: Execute commands to completion with buffered output
- `start()`: Long-running processes with streaming stdout/stderr

**Native Process Management**
- FFI-based process execution for Windows x64 and Linux x64
- Non-blocking I/O for stdout and stderr streams
- Exit code handling and process lifecycle management
- Process timeouts and cancellation support

**Sandboxing**
- Windows: AppContainer integration for isolated process execution
- Linux: Bubblewrap (bwrap) support with filesystem isolation
- Configurable via `WorkspaceOptions.sandbox`
- Automatic fallback to non-sandboxed mode when unavailable

**File Operations**
- `writeFile()`: Write text files relative to workspace root
- `readFile()`: Read text files from workspace
- `exists()`: Check file/directory existence
- `createDir()`: Create directories
- `delete()`: Remove files or directories

**Configuration**
- Configurable timeouts for command execution
- Custom environment variables
- Working directory overrides
- Parent environment inheritance control

**Testing & Quality**
- Integration tests for process execution
- Concurrency and stress tests (10+ concurrent workspaces)
- Security validation tests
- Streaming output tests
- Unit tests for command result and shell parsing
- Cross-platform coverage (Windows & Linux)

### Technical Details

- Built with `dart:ffi` for native C++ interop
- Native core in C++ with platform-specific implementations
- CMake-based build system
- Prebuilt binaries for Windows x64 and Linux x64

### Documentation

- Comprehensive README with examples and API docs
- Inline documentation for all public APIs
- Security notes and best practices for AI agent use cases
- Platform support matrix and known limitations

---

[0.1.6]: https://github.com/CarlosHuamaniTec/workspace_sandbox/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/CarlosHuamaniTec/workspace_sandbox/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/CarlosHuamaniTec/workspace_sandbox/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/CarlosHuamaniTec/workspace_sandbox/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/CarlosHuamaniTec/workspace_sandbox/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/CarlosHuamaniTec/workspace_sandbox/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/CarlosHuamaniTec/workspace_sandbox/releases/tag/v0.1.0

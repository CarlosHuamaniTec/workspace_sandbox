# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 2025-11-21

### 🎉 Initial Release

First public release of `workspace_sandbox` - a cross-platform sandboxed workspace manager for running shell commands with native isolation.

### ✨ Added

- **Core Workspace API**
  - `Workspace.secure()` - Creates ephemeral temporary workspaces with automatic cleanup
  - `Workspace.host(path)` - Uses existing directories as workspace roots
  - `run()` method for executing commands to completion with buffered output
  - `start()` method for long-running processes with streaming stdout/stderr

- **Native Process Management**
  - FFI-based process execution for Windows x64 and Linux x64
  - Non-blocking I/O for stdout and stderr streams
  - Proper exit code handling and process lifecycle management
  - Support for process timeouts and cancellation

- **Sandboxing**
  - Windows AppContainer integration for isolated process execution
  - Linux bubblewrap (bwrap) support with filesystem isolation
  - Configurable sandbox mode via `WorkspaceOptions.sandbox`
  - Automatic fallback to non-sandboxed mode when sandbox unavailable

- **File Operations**
  - `writeFile()` - Write text files relative to workspace root
  - `readFile()` - Read text files from workspace
  - `exists()` - Check file/directory existence
  - `createDir()` - Create directories
  - `delete()` - Delete files or directories

- **Configuration Options**
  - Configurable timeouts for command execution
  - Custom environment variables
  - Working directory overrides
  - Parent environment inheritance control

- **Testing & Quality**
  - Comprehensive integration tests for process execution
  - Concurrency and stress tests (10+ concurrent workspaces)
  - Security validation tests for sandbox behavior
  - Streaming output tests
  - Unit tests for command result parsing and shell parsing
  - Cross-platform test coverage (Windows & Linux)

### 🏗️ Technical Details

- Built with `dart:ffi` for native C++ interop
- Native core written in C++ with platform-specific implementations
- CMake-based build system for native libraries
- Prebuilt binaries included for Windows x64 and Linux x64

### 📝 Documentation

- Comprehensive README with examples and API documentation
- Inline API documentation for all public classes and methods
- Security notes and best practices for AI agent use cases
- Platform support matrix and known limitations

### 🔒 Security

- Optional native sandboxing on Windows (AppContainer) and Linux (bubblewrap)
- Process isolation to prevent escape from workspace root
- Timeout enforcement to prevent runaway processes
- Clear security guidance for AI agent developers

---

## [Unreleased]

### Planned Features

- macOS support (darwin x64 and arm64)
- ARM architecture support for Linux and Windows
- Enhanced sandbox capabilities (network isolation, resource limits)
- Interactive TTY support for certain command types
- Process signal handling (SIGINT, SIGTERM)
- Windows Job Object integration for better resource management

---

[0.1.0]: https://github.com/deskhand-software/workspace_sandbox/releases/tag/v0.1.0

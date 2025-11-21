#ifndef _WIN32
#include "../common/internal_api.h"
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <vector>
#include <cstring>
#include <errno.h>
#include <sstream>
#include <string>

/// Small helper to build argv-style argument vectors.
///
/// Owns the underlying std::string storage and returns a
/// null-terminated array of `char*` suitable for execvp.
class ArgBuilder {
  std::vector<std::string> storage;

public:
  void add(const std::string& arg) {
    storage.push_back(arg);
  }

  std::vector<char*> getArgs() {
    std::vector<char*> ptrs;
    ptrs.reserve(storage.size() + 1);
    for (auto& s : storage) {
      ptrs.push_back(const_cast<char*>(s.c_str()));
    }
    ptrs.push_back(nullptr);
    return ptrs;
  }

  bool empty() const { return storage.empty(); }
  size_t size() const { return storage.size(); }

  /// Appends a minimal bubblewrap sandbox configuration.
  ///
  /// This isolates the process in new namespaces and bind-mounts
  /// a mostly read-only filesystem with a few writable/real paths.
  void add_bwrap_base() {
    add("bwrap");
    add("--unshare-all");
    add("--share-net");
    add("--die-with-parent");
    add("--cap-drop"); add("ALL");
    add("--ro-bind"); add("/"); add("/");
    add("--dev-bind"); add("/dev"); add("/dev");
    add("--proc"); add("/proc");
    add("--tmpfs"); add("/tmp");
    add("--ro-bind"); add("/usr"); add("/usr");
    add("--ro-bind"); add("/bin"); add("/bin");
  }
};

/// Sets a file descriptor to non-blocking mode.
static void set_nonblocking(int fd) {
  int flags = fcntl(fd, F_GETFL, 0);
  if (flags != -1) fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

/// Simple command-line parser with basic quote handling.
///
/// Splits a single command line into argv-style parts, honoring
/// single and double quotes and backslash escapes.
static std::vector<std::string> parse_command_line(const char* command_line) {
  std::vector<std::string> parts;
  if (!command_line || !*command_line) return parts;

  std::string cmd(command_line);
  std::string current;
  bool inSingleQuote = false;
  bool inDoubleQuote = false;
  bool escape = false;

  for (size_t i = 0; i < cmd.length(); ++i) {
    char c = cmd[i];

    if (escape) {
      current += c;
      escape = false;
      continue;
    }

    if (c == '\\' && !inSingleQuote) {
      escape = true;
      continue;
    }

    if (c == '\'' && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote;
      continue;
    }

    if (c == '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      continue;
    }

    if ((c == ' ' || c == '\t') && !inSingleQuote && !inDoubleQuote) {
      if (!current.empty()) {
        parts.push_back(current);
        current.clear();
      }
      continue;
    }

    current += c;
  }

  if (!current.empty()) {
    parts.push_back(current);
  }

  return parts;
}

/// Starts a process on Linux, optionally inside a bubblewrap sandbox.
///
/// When [sandbox] is true, the command is executed as:
///   bwrap <base args> [bind workspace cwd] <original argv...>
ProcessHandle* StartProcessLinux(
  const char* command_line,
  const char* cwd,
  bool sandbox,
  const char* id
) {
  auto parsed = parse_command_line(command_line);
  if (parsed.empty()) {
    return nullptr;
  }

  ArgBuilder args;

  if (sandbox) {
    args.add_bwrap_base();

    if (cwd && *cwd) {
      args.add("--bind");
      args.add(cwd);
      args.add(cwd);
      args.add("--chdir");
      args.add(cwd);
    }

    for (const auto& part : parsed) {
      args.add(part);
    }
  } else {
    for (const auto& part : parsed) {
      args.add(part);
    }
  }

  auto exec_args = args.getArgs();

  int pipeOut[2], pipeErr[2], pipeExec[2];

  if (pipe(pipeOut) == -1) return nullptr;
  if (pipe(pipeErr) == -1) {
    close(pipeOut[0]); close(pipeOut[1]);
    return nullptr;
  }
  if (pipe(pipeExec) == -1) {
    close(pipeOut[0]); close(pipeOut[1]);
    close(pipeErr[0]); close(pipeErr[1]);
    return nullptr;
  }

  fcntl(pipeExec[1], F_SETFD, FD_CLOEXEC);

  pid_t pid = fork();
  if (pid == -1) {
    close(pipeOut[0]); close(pipeOut[1]);
    close(pipeErr[0]); close(pipeErr[1]);
    close(pipeExec[0]); close(pipeExec[1]);
    return nullptr;
  }

  if (pid == 0) {
    // Child
    close(pipeOut[0]);
    close(pipeErr[0]);
    close(pipeExec[0]);

    if (dup2(pipeOut[1], STDOUT_FILENO) == -1) _exit(errno);
    if (dup2(pipeErr[1], STDERR_FILENO) == -1) _exit(errno);

    close(pipeOut[1]);
    close(pipeErr[1]);

    // When not sandboxed, honour cwd directly.
    if (cwd && *cwd && !sandbox) {
      if (chdir(cwd) == -1) {
        int err = errno;
        write(pipeExec[1], &err, sizeof(err));
        _exit(1);
      }
    }

    execvp(exec_args[0], exec_args.data());
    int err = errno;
    write(pipeExec[1], &err, sizeof(err));
    _exit(1);
  } else {
    // Parent
    close(pipeOut[1]);
    close(pipeErr[1]);
    close(pipeExec[1]);

    int errCode = 0;
    ssize_t readSz = read(pipeExec[0], &errCode, sizeof(errCode));
    close(pipeExec[0]);

    if (readSz > 0) {
      // execvp failed in child
      close(pipeOut[0]);
      close(pipeErr[0]);
      waitpid(pid, NULL, 0);
      return nullptr;
    }

    set_nonblocking(pipeOut[0]);
    set_nonblocking(pipeErr[0]);

    ProcessHandle* handle = new ProcessHandle();
    handle->pid = pid;
    handle->fdOut = pipeOut[0];
    handle->fdErr = pipeErr[0];
    handle->isRunning = true;
    handle->exitCode = -1;
    return handle;
  }
}
#endif

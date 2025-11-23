//! Linux isolation using Bubblewrap with root passthrough strategy.

use super::base::{ExecutionContext, IsolationStrategy};
use anyhow::{Context, Result};
use std::env;
use std::fs;
use std::path::Path;
use std::process::{Command, Stdio};
use which::which;

pub struct LinuxBwrapStrategy;

impl IsolationStrategy for LinuxBwrapStrategy {
    fn name(&self) -> &'static str {
        "Linux Bubblewrap (Root Passthrough)"
    }

    #[allow(clippy::too_many_lines)]
    fn build_command(&self, ctx: &ExecutionContext) -> Result<Command> {
        let bwrap_path = which("bwrap")
            .context("bwrap not found. Install with: sudo apt install bubblewrap")?;
        let mut command = Command::new(bwrap_path);

        command
            .arg("--die-with-parent")
            .arg("--unshare-pid")
            .arg("--unshare-ipc")
            .arg("--unshare-uts");

        if ctx.allow_network {
            command.arg("--share-net");
        } else {
            command.arg("--unshare-net");
        }

        command.arg("--ro-bind").arg("/").arg("/");

        command
            .arg("--dev")
            .arg("/dev")
            .arg("--proc")
            .arg("/proc")
            .arg("--tmpfs")
            .arg("/tmp")
            .arg("--tmpfs")
            .arg("/var/tmp")
            .arg("--tmpfs")
            .arg("/root")
            .arg("--tmpfs")
            .arg("/run");

        if let Ok(_resolv_target) = fs::read_link("/etc/resolv.conf") {
            if let Ok(real_path) = fs::canonicalize("/etc/resolv.conf") {
                let real_path_str = real_path.to_string_lossy();

                if real_path_str.starts_with("/run") {
                    if let Some(parent) = real_path.parent() {
                        command
                            .arg("--dir")
                            .arg(parent.to_string_lossy().to_string());
                    }
                    command
                        .arg("--ro-bind")
                        .arg(&real_path)
                        .arg(&real_path);
                }
            }
        } else if Path::new("/etc/resolv.conf").exists() {
            command
                .arg("--ro-bind")
                .arg("/etc/resolv.conf")
                .arg("/etc/resolv.conf");
        }

        if let Ok(home) = env::var("HOME") {
            let home_path = Path::new(&home);
            if home_path.exists() {
                command.arg("--tmpfs").arg(&home);

                let tool_caches = [
                    ".m2",
                    ".gradle",
                    ".npm",
                    ".pub-cache",
                    ".cargo",
                    ".rustup",
                    ".local/share/pnpm",
                    "go/pkg",
                    ".config/gcloud",
                    ".flutter",
                ];

                for cache_dir in tool_caches {
                    let source_path = home_path.join(cache_dir);
                    if source_path.exists() {
                        let dest_path = format!("{home}/{cache_dir}");
                        command
                            .arg("--ro-bind")
                            .arg(source_path.to_string_lossy().to_string())
                            .arg(dest_path);
                    }
                }
            }
        }

        command
            .arg("--bind")
            .arg(&ctx.root_path)
            .arg(&ctx.root_path)
            .arg("--chdir")
            .arg(&ctx.root_path);

        command.env_clear();
        let keep_vars = [
            "PATH",
            "JAVA_HOME",
            "FLUTTER_ROOT",
            "GOPATH",
            "TERM",
            "LANG",
            "HOME",
            "SHELL",
        ];
        for k in keep_vars {
            if let Ok(v) = env::var(k) {
                command.env(k, v);
            }
        }
        for (key, val) in &ctx.env_vars {
            command.env(key, val);
        }

        command
            .arg("--")
            .arg(&ctx.cmd)
            .args(&ctx.args)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        Ok(command)
    }
}

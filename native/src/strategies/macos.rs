//! macOS isolation using Seatbelt (sandbox-exec).

use super::base::{ExecutionContext, IsolationStrategy};
use anyhow::Result;
use std::env;
use std::path::Path;
use std::process::{Command, Stdio};

pub struct MacOsSandboxStrategy;

impl IsolationStrategy for MacOsSandboxStrategy {
    fn name(&self) -> &'static str {
        "macOS Seatbelt (Read-Only Host)"
    }

    fn build_command(&self, ctx: &ExecutionContext) -> Result<Command> {
        let sandbox_exec = "/usr/bin/sandbox-exec";

        if !Path::new(sandbox_exec).exists() {
            return Err(anyhow::anyhow!("sandbox-exec not found on this system"));
        }

        let home = env::var("HOME").unwrap_or_else(|_| "/var/tmp".to_string());

        let network_policy = if ctx.allow_network {
            "(allow network*)"
        } else {
            "(deny network*)"
        };

        let profile = format!(
            r#"
            (version 1)
            (allow default)
            
            (deny file-write* (subpath "/"))

            (allow file-write*
                (subpath "{workspace}")
                (subpath "/private/var/folders")
                (subpath "/tmp")
                (subpath "/var/tmp")
                (subpath "/Users/Shared")
                (subpath "{home}/.m2")
                (subpath "{home}/.gradle")
                (subpath "{home}/.dart_tool")
            )

            {network_policy}
            
            (allow process-exec)
            (allow process-fork)
            (allow mach-lookup)
            "#,
            workspace = ctx.root_path,
            home = home,
            network_policy = network_policy
        );

        let mut command = Command::new(sandbox_exec);
        command.arg("-p").arg(profile);
        command.arg(&ctx.cmd).args(&ctx.args);

        command.env_clear();
        command.envs(env::vars());
        command.envs(&ctx.env_vars);

        if let Some(cwd) = &ctx.cwd {
            command.current_dir(cwd);
        } else {
            command.current_dir(&ctx.root_path);
        }

        command
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        Ok(command)
    }
}

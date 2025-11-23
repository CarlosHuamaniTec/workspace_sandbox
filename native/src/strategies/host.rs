//! Fallback strategy that executes commands without isolation.

use super::base::{ExecutionContext, IsolationStrategy};
use anyhow::Result;
use std::process::{Command, Stdio};
use which::which;

pub struct HostStrategy;

impl IsolationStrategy for HostStrategy {
    fn name(&self) -> &'static str {
        "Host (No Isolation)"
    }

    fn build_command(&self, ctx: &ExecutionContext) -> Result<Command> {
        let mut program = ctx.cmd.clone();
        let mut args = ctx.args.clone();

        if cfg!(windows) {
            let cmd_lower = program.to_lowercase();
            let builtins = [
                "echo", "dir", "del", "copy", "move", "mkdir", "rmdir", "type", "cls", "ping",
            ];

            if builtins.contains(&cmd_lower.as_str()) {
                args.insert(0, "/c".to_string());
                args.insert(1, program.clone());
                program = "cmd".to_string();
            }
        }

        let resolved_program = if program == "cmd" {
            "cmd".into()
        } else {
            which(&program).unwrap_or_else(|_| program.clone().into())
        };

        let mut command = Command::new(resolved_program);
        command
            .args(&args)
            .envs(&ctx.env_vars)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        if let Some(cwd) = &ctx.cwd {
            command.current_dir(cwd);
        } else {
            command.current_dir(&ctx.root_path);
        }

        Ok(command)
    }
}

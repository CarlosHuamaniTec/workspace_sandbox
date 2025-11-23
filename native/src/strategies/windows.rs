//! Windows isolation using Job Objects for process grouping.

use super::base::{ExecutionContext, IsolationStrategy};
use anyhow::Result;
use std::process::{Command, Stdio};
use which::which;

#[cfg(windows)]
use windows::Win32::System::JobObjects::{
    AssignProcessToJobObject, CreateJobObjectW, JobObjectExtendedLimitInformation,
    SetInformationJobObject, JOBOBJECT_EXTENDED_LIMIT_INFORMATION,
    JOB_OBJECT_LIMIT_BREAKAWAY_OK, JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
};
#[cfg(windows)]
use windows::Win32::System::Threading::GetCurrentProcess;

pub struct WindowsJobStrategy;

impl IsolationStrategy for WindowsJobStrategy {
    fn name(&self) -> &'static str {
        "Windows Job Object (Process Grouping)"
    }

    fn build_command(&self, ctx: &ExecutionContext) -> Result<Command> {
        let mut program = ctx.cmd.clone();
        let mut args = ctx.args.clone();
        let prog_lower = program.to_lowercase();

        let builtins = [
            "echo", "dir", "del", "copy", "move", "mkdir", "rmdir", "type", "cls", "ping", "ver",
        ];
        let is_batch = prog_lower.ends_with(".bat") || prog_lower.ends_with(".cmd");

        if builtins.contains(&prog_lower.as_str()) || is_batch {
            args.insert(0, "/c".to_string());
            args.insert(1, program.clone());
            program = "cmd".to_string();
        }

        let resolved_program = if program == "cmd" {
            "cmd".into()
        } else {
            which(&program).unwrap_or_else(|_| program.clone().into())
        };

        let mut command = Command::new(resolved_program);
        command.args(&args);

        command.env_clear();
        let critical_vars = [
            "SystemRoot",
            "windir",
            "PATH",
            "PATHEXT",
            "COMSPEC",
            "TEMP",
            "TMP",
            "USERPROFILE",
            "JAVA_HOME",
        ];

        for k in critical_vars {
            if let Ok(v) = std::env::var(k) {
                command.env(k, v);
            }
        }
        command.envs(&ctx.env_vars);

        if !ctx.allow_network {
            command.env("HTTP_PROXY", "http://0.0.0.0:0");
            command.env("HTTPS_PROXY", "http://0.0.0.0:0");
            command.env("ALL_PROXY", "socks5://0.0.0.0:0");
            command.env("NO_PROXY", "");
        }

        if let Some(cwd) = &ctx.cwd {
            command.current_dir(cwd);
        } else {
            command.current_dir(&ctx.root_path);
        }

        command
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        #[cfg(windows)]
        unsafe {
            let job = CreateJobObjectW(None, None)?;
            let mut info = JOBOBJECT_EXTENDED_LIMIT_INFORMATION::default();
            info.BasicLimitInformation.LimitFlags =
                JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE | JOB_OBJECT_LIMIT_BREAKAWAY_OK;

            SetInformationJobObject(
                job,
                JobObjectExtendedLimitInformation,
                &info as *const _ as *const _,
                std::mem::size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
            )?;

            AssignProcessToJobObject(job, GetCurrentProcess())?;
        }

        Ok(command)
    }
}

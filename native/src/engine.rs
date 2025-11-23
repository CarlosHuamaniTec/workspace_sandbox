//! Core execution engine for managing isolated process lifecycles.

use anyhow::{anyhow, Result};
use std::process::Stdio;
#[cfg(unix)]
use tokio::signal::unix::{signal, SignalKind};
#[cfg(windows)]
use tokio::signal;

#[cfg(unix)]
use std::os::unix::process::ExitStatusExt;

use crate::strategies::base::{ExecutionContext, IsolationStrategy};
use crate::strategies::host::HostStrategy;

#[cfg(target_os = "linux")]
use crate::strategies::linux::LinuxBwrapStrategy;
#[cfg(target_os = "macos")]
use crate::strategies::macos::MacOsSandboxStrategy;
#[cfg(target_os = "windows")]
use crate::strategies::windows::WindowsJobStrategy;

pub struct Engine {
    strategy: Box<dyn IsolationStrategy>,
}

impl Engine {
    #[must_use]
    pub fn new(sandbox: bool) -> Self {
        let strategy: Box<dyn IsolationStrategy> = if sandbox {
            #[cfg(target_os = "linux")]
            {
                Box::new(LinuxBwrapStrategy)
            }
            #[cfg(target_os = "windows")]
            {
                Box::new(WindowsJobStrategy)
            }
            #[cfg(target_os = "macos")]
            {
                Box::new(MacOsSandboxStrategy)
            }
            #[cfg(not(any(target_os = "linux", target_os = "windows", target_os = "macos")))]
            {
                Box::new(HostStrategy)
            }
        } else {
            Box::new(HostStrategy)
        };

        Engine { strategy }
    }

    pub async fn run(&self, ctx: ExecutionContext) -> Result<i32> {
        eprintln!("[Launcher] Strategy: {}", self.strategy.name());
        eprintln!("[Launcher] Command: {} {:?}", ctx.cmd, ctx.args);

        let cmd = self.strategy.build_command(&ctx)?;

        let mut child = tokio::process::Command::from(cmd)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .stdin(Stdio::null())
            .kill_on_drop(true)
            .spawn()
            .map_err(|e| anyhow!("Process spawn failed: {e}"))?;

        if let Some(pid) = child.id() {
            eprintln!("[Launcher] PID: {pid}");
        }

        let mut child_stdout = child.stdout.take().expect("stdout not captured");
        let mut child_stderr = child.stderr.take().expect("stderr not captured");

        let stdout_task = tokio::spawn(async move {
            let mut stdout = tokio::io::stdout();
            let _ = tokio::io::copy(&mut child_stdout, &mut stdout).await;
        });

        let stderr_task = tokio::spawn(async move {
            let mut stderr = tokio::io::stderr();
            let _ = tokio::io::copy(&mut child_stderr, &mut stderr).await;
        });

        let exit_status = tokio::select! {
            status = child.wait() => status,
            () = wait_for_termination() => {
                eprintln!("[Launcher] Received termination signal");
                let _ = child.kill().await;
                return Ok(-1);
            }
        };

        let _ = tokio::join!(stdout_task, stderr_task);

        let status = exit_status.map_err(|e| anyhow!("Failed to wait for process: {e}"))?;
        let code = status.code().unwrap_or(-1);

        #[cfg(unix)]
        if let Some(sig) = status.signal() {
            eprintln!("[Launcher] Killed by signal {sig}");
            return Ok(-1);
        }

        eprintln!("[Launcher] Exit code: {code}");
        Ok(code)
    }
}

async fn wait_for_termination() {
    #[cfg(unix)]
    {
        let mut sigterm = signal(SignalKind::terminate()).expect("Failed to register SIGTERM");
        let mut sigint = signal(SignalKind::interrupt()).expect("Failed to register SIGINT");
        tokio::select! {
            _ = sigterm.recv() => {},
            _ = sigint.recv() => {},
        };
    }
    #[cfg(windows)]
    {
        let _ = signal::ctrl_c().await;
    }
}

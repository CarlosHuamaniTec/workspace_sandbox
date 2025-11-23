//! Native launcher for `workspace_sandbox` isolation.
//!
//! This binary provides cross-platform sandboxing capabilities for executing
//! commands in isolated environments. It's invoked by the Dart `workspace_sandbox`
//! package and should not be called directly by end users.

#![warn(clippy::all, clippy::pedantic)]
#![allow(clippy::missing_errors_doc, clippy::missing_panics_doc)]

mod engine;
mod strategies;

use crate::engine::Engine;
use crate::strategies::base::ExecutionContext;
use clap::Parser;
use std::process;

#[derive(Parser, Debug)]
#[command(
    name = "workspace_launcher",
    version,
    about = "Native isolation launcher for workspace_sandbox",
    long_about = "Executes commands in isolated environments using platform-specific sandboxing"
)]
struct Args {
    #[arg(long)]
    id: String,

    #[arg(long)]
    workspace: String,

    #[arg(long)]
    sandbox: bool,

    #[arg(long)]
    no_net: bool,

    #[arg(long)]
    cwd: Option<String>,

    #[arg(long, value_parser = parse_key_val)]
    env: Vec<(String, String)>,

    #[arg(last = true)]
    command: Vec<String>,
}

fn parse_key_val(s: &str) -> Result<(String, String), String> {
    let pos = s
        .find('=')
        .ok_or_else(|| format!("Invalid KEY=value format: no '=' found in `{s}`"))?;
    Ok((s[..pos].to_string(), s[pos + 1..].to_string()))
}

#[tokio::main]
async fn main() {
    let args = Args::parse();

    if args.command.is_empty() {
        eprintln!("[Launcher] ERROR: No command provided");
        process::exit(98);
    }

    let ctx = ExecutionContext {
        id: args.id,
        root_path: args.workspace,
        cmd: args.command[0].clone(),
        args: args.command[1..].to_vec(),
        env_vars: args.env.into_iter().collect(),
        cwd: args.cwd,
        allow_network: !args.no_net,
    };

    let engine = Engine::new(args.sandbox);

    match engine.run(ctx).await {
        Ok(code) => process::exit(code),
        Err(e) => {
            eprintln!("[Launcher] FATAL ERROR: {e:#}");
            process::exit(99);
        }
    }
}

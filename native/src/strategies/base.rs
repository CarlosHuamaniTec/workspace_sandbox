//! Core traits and types for isolation strategies.

use anyhow::Result;
use std::collections::HashMap;
use std::process::Command;

#[derive(Debug)]
pub struct ExecutionContext {
    #[allow(dead_code)]
    pub id: String,
    
    pub root_path: String,
    pub cmd: String,
    pub args: Vec<String>,
    pub env_vars: HashMap<String, String>,
    pub cwd: Option<String>,
    pub allow_network: bool,
}

pub trait IsolationStrategy: Send + Sync {
    fn build_command(&self, ctx: &ExecutionContext) -> Result<Command>;
    fn name(&self) -> &'static str;
}

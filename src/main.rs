#![allow(
    dead_code,
    clippy::too_many_arguments,
    clippy::manual_strip,
    clippy::if_same_then_else,
    clippy::vec_init_then_push,
    clippy::upper_case_acronyms,
    clippy::format_in_format_args,
    clippy::enum_variant_names,
    clippy::module_inception,
    clippy::doc_lazy_continuation,
    clippy::manual_clamp,
    clippy::type_complexity
)]
#![forbid(unsafe_code)]
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// k9iser CLI — Wrap configs and deployments into self-validating K9 contracts.
//
// Subcommands:
//   init      — create a new k9iser.toml manifest with K9 contract pillars
//   validate  — validate a k9iser.toml manifest for correctness
//   generate  — parse configs and generate .k9 contract files
//   build     — validate configs against their contracts
//   run       — confirm contracts pass and print deployment summary
//   info      — show manifest information

use anyhow::Result;
use clap::{Parser, Subcommand};

mod abi;
mod codegen;
mod manifest;

/// k9iser — Wrap configs and deployments into self-validating K9 contracts
#[derive(Parser)]
#[command(name = "k9iser", version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Initialise a new k9iser.toml manifest.
    Init {
        #[arg(short, long, default_value = ".")]
        path: String,
    },
    /// Validate a k9iser.toml manifest.
    Validate {
        #[arg(short, long, default_value = "k9iser.toml")]
        manifest: String,
    },
    /// Generate K9 contract files from configs and manifest rules.
    Generate {
        #[arg(short, long, default_value = "k9iser.toml")]
        manifest: String,
        #[arg(short, long, default_value = "generated/k9iser")]
        output: String,
    },
    /// Build: validate configs against their generated contracts.
    Build {
        #[arg(short, long, default_value = "k9iser.toml")]
        manifest: String,
        #[arg(long)]
        release: bool,
    },
    /// Run the validated config deployment.
    Run {
        #[arg(short, long, default_value = "k9iser.toml")]
        manifest: String,
        #[arg(trailing_var_arg = true)]
        args: Vec<String>,
    },
    /// Show manifest information.
    Info {
        #[arg(short, long, default_value = "k9iser.toml")]
        manifest: String,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Commands::Init { path } => {
            manifest::init_manifest(&path)?;
        }
        Commands::Validate { manifest } => {
            let m = manifest::load_manifest(&manifest)?;
            manifest::validate(&m)?;
            let name = manifest::effective_project_name(&m);
            println!("Valid: {}", name);
        }
        Commands::Generate { manifest, output } => {
            let m = manifest::load_manifest(&manifest)?;
            manifest::validate(&m)?;
            let manifest_dir = std::path::Path::new(&manifest)
                .parent()
                .unwrap_or(std::path::Path::new("."));
            codegen::generate_all_from(&m, &output, manifest_dir)?;
        }
        Commands::Build { manifest, release } => {
            let m = manifest::load_manifest(&manifest)?;
            manifest::validate(&m)?;
            codegen::build(&m, release)?;
        }
        Commands::Run { manifest, args } => {
            let m = manifest::load_manifest(&manifest)?;
            manifest::validate(&m)?;
            codegen::run(&m, &args)?;
        }
        Commands::Info { manifest } => {
            let m = manifest::load_manifest(&manifest);
            match m {
                Ok(m) => manifest::print_info(&m),
                Err(e) => eprintln!("Failed to load manifest: {}", e),
            }
        }
    }
    Ok(())
}

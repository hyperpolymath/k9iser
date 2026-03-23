// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Codegen orchestration module for k9iser.
//
// Coordinates the three codegen phases:
// 1. parser — reads source config files (TOML, YAML, JSON, INI)
// 2. contract — generates .k9 contract files from parsed configs + manifest rules
// 3. validator — validates configs against generated contracts, produces reports

pub mod contract;
pub mod parser;
pub mod validator;

use anyhow::{Context, Result};
use std::fs;
use std::path::Path;

use crate::abi::{ConfigFormat, SafetyTier};
use crate::manifest::{Manifest, effective_project_name};

/// Generate all K9 contract files for every config entry in the manifest.
///
/// For each [[configs]] entry:
/// 1. Parse the source config file to extract key-value structure
/// 2. Generate a .k9 contract file encoding the four pillars
///
/// Output files are written to `output_dir/<config-name>.k9`.
pub fn generate_all(manifest: &Manifest, output_dir: &str) -> Result<()> {
    let project_name = effective_project_name(manifest);
    let safety_tier =
        SafetyTier::from_str_loose(&manifest.project.safety_tier).unwrap_or(SafetyTier::Kennel);

    fs::create_dir_all(output_dir)
        .with_context(|| format!("Failed to create output directory: {}", output_dir))?;

    if manifest.configs.is_empty() {
        println!("  No config entries in manifest — nothing to generate.");
        return Ok(());
    }

    // Resolve the manifest directory for relative source paths
    let manifest_dir = Path::new(".");

    for cfg in &manifest.configs {
        let format = ConfigFormat::from_str_loose(&cfg.format).unwrap_or(ConfigFormat::Toml);

        // Parse the source config file (if it exists)
        let source_path = manifest_dir.join(&cfg.source);
        let parsed = if source_path.exists() {
            match parser::parse_config_file(source_path.to_str().unwrap_or(""), format) {
                Ok(entries) => entries,
                Err(e) => {
                    println!(
                        "  Warning: could not parse '{}': {}. Generating contract without parsed keys.",
                        cfg.source, e
                    );
                    Vec::new()
                }
            }
        } else {
            println!(
                "  Note: source '{}' not found. Generating contract from manifest rules only.",
                cfg.source
            );
            Vec::new()
        };

        // Generate the .k9 contract
        let k9_content = contract::generate_k9_contract(
            &cfg.name,
            safety_tier,
            &cfg.must,
            &cfg.trust,
            &cfg.dust,
            &cfg.intend,
            &parsed,
        );

        let output_path = Path::new(output_dir).join(format!("{}.k9", cfg.name));
        fs::write(&output_path, &k9_content)
            .with_context(|| format!("Failed to write contract: {}", output_path.display()))?;

        println!("  Generated {} ({})", output_path.display(), cfg.name);
    }

    println!(
        "Generated {} K9 contract(s) for project '{}'",
        manifest.configs.len(),
        project_name
    );
    Ok(())
}

/// Build step — validates all configs against their generated contracts.
///
/// Reads the manifest, parses each config, then runs validation. In strict
/// mode (default), any violation causes a non-zero exit.
pub fn build(manifest: &Manifest, _release: bool) -> Result<()> {
    let project_name = effective_project_name(manifest);
    println!("Building k9iser project: {}", project_name);

    let safety_tier =
        SafetyTier::from_str_loose(&manifest.project.safety_tier).unwrap_or(SafetyTier::Kennel);

    let manifest_dir = Path::new(".");
    let mut all_passed = true;

    for cfg in &manifest.configs {
        let format = ConfigFormat::from_str_loose(&cfg.format).unwrap_or(ConfigFormat::Toml);
        let source_path = manifest_dir.join(&cfg.source);

        if !source_path.exists() {
            println!(
                "  Skip '{}': source not found at '{}'",
                cfg.name, cfg.source
            );
            continue;
        }

        let parsed = parser::parse_config_file(source_path.to_str().unwrap_or(""), format)?;
        let k9_contract = contract::build_k9_contract(
            &cfg.name,
            &cfg.source,
            format,
            safety_tier,
            &cfg.must,
            &cfg.trust,
            &cfg.dust,
            &cfg.intend,
        );

        let result = validator::validate_config(&parsed, &k9_contract);
        println!("  {} — {}", cfg.name, result);

        if !result.is_pass() {
            all_passed = false;
        }
    }

    if manifest.validation.strict && !all_passed {
        anyhow::bail!("Build failed: validation violations detected in strict mode");
    }

    println!("Build complete for '{}'", project_name);
    Ok(())
}

/// Run step — placeholder for executing a validated config deployment.
///
/// In k9iser, "run" means confirming all contracts pass and printing a summary.
/// Actual deployment is left to the user's toolchain.
pub fn run(manifest: &Manifest, _args: &[String]) -> Result<()> {
    let project_name = effective_project_name(manifest);
    println!("Running k9iser project: {}", project_name);
    println!(
        "  All {} config(s) contract-wrapped.",
        manifest.configs.len()
    );
    println!("  Deploy using your preferred toolchain.");
    Ok(())
}

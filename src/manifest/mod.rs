// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Manifest module for k9iser — parses k9iser.toml manifests that describe
// config files to be wrapped into self-validating K9 contracts.
//
// The manifest uses a K9-specific schema with:
// - [project] — project name and safety tier
// - [[configs]] — config file entries with four K9 pillars (must/trust/dust/intend)
// - [validation] — validation behaviour options
//
// Backward compatibility: if a [workload] section is present (old format),
// it is accepted and mapped into the new schema.

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::Path;

use crate::abi::{ConfigFormat, SafetyTier};

// ---------------------------------------------------------------------------
// New K9-specific manifest types
// ---------------------------------------------------------------------------

/// Top-level k9iser manifest, deserialised from k9iser.toml.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    /// Project-level metadata.
    pub project: ProjectConfig,
    /// Config file entries, each wrapped into a K9 contract.
    #[serde(default)]
    pub configs: Vec<ConfigEntry>,
    /// Validation behaviour options.
    #[serde(default)]
    pub validation: ValidationConfig,

    // --- Backward compatibility: old-format workload section ---
    /// Legacy workload section (optional). If present, the project name is
    /// taken from here when project.name is empty.
    #[serde(default)]
    pub workload: Option<WorkloadConfig>,
}

/// Project-level configuration: name and safety tier.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectConfig {
    /// Human-readable project name.
    pub name: String,
    /// Safety tier: "kennel" (low), "yard" (medium), or "hunt" (high).
    #[serde(rename = "safety-tier", default = "default_safety_tier")]
    pub safety_tier: String,
}

fn default_safety_tier() -> String {
    "kennel".to_string()
}

/// A single config file entry with K9 contract pillars.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigEntry {
    /// Logical name for this config entry.
    pub name: String,
    /// Path to the source config file (relative to manifest).
    pub source: String,
    /// Config file format: toml, yaml, json, or ini.
    #[serde(default = "default_format")]
    pub format: String,
    /// Must rules — required constraints (e.g. "port > 0").
    #[serde(default)]
    pub must: Vec<String>,
    /// Trust sources — verified origins (e.g. "signed-by: ci-pipeline").
    #[serde(default)]
    pub trust: Vec<String>,
    /// Dust rules — cleanup actions (e.g. "remove: deprecated-keys").
    #[serde(default)]
    pub dust: Vec<String>,
    /// Intend declarations — purpose statements (e.g. "production-ready").
    #[serde(default)]
    pub intend: Vec<String>,
}

fn default_format() -> String {
    "toml".to_string()
}

/// Validation behaviour configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationConfig {
    /// If true, fail on any violation. Default: true.
    #[serde(default = "default_true")]
    pub strict: bool,
    /// If true, automatically apply dust rules. Default: false.
    #[serde(rename = "auto-fix", default)]
    pub auto_fix: bool,
    /// Report output format: text, json, or a2ml. Default: text.
    #[serde(rename = "report-format", default = "default_report_format")]
    pub report_format: String,
}

fn default_true() -> bool {
    true
}

fn default_report_format() -> String {
    "text".to_string()
}

impl Default for ValidationConfig {
    fn default() -> Self {
        Self {
            strict: true,
            auto_fix: false,
            report_format: "text".to_string(),
        }
    }
}

// ---------------------------------------------------------------------------
// Legacy workload types (backward compatibility)
// ---------------------------------------------------------------------------

/// Legacy workload configuration from older k9iser manifests.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkloadConfig {
    pub name: String,
    #[serde(default)]
    pub entry: String,
    #[serde(default)]
    pub strategy: String,
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Load and deserialise a k9iser.toml manifest from the given file path.
pub fn load_manifest(path: &str) -> Result<Manifest> {
    let content =
        std::fs::read_to_string(path).with_context(|| format!("Failed to read: {}", path))?;
    let manifest: Manifest =
        toml::from_str(&content).with_context(|| format!("Failed to parse: {}", path))?;
    Ok(manifest)
}

/// Validate the manifest for required fields and consistency.
///
/// Checks:
/// - project.name must not be empty (or workload.name for legacy manifests)
/// - safety-tier must be a valid SafetyTier value
/// - each config entry must have a non-empty name and source
/// - each config entry format must be a recognised ConfigFormat
pub fn validate(manifest: &Manifest) -> Result<()> {
    // Check project name (allow legacy workload.name as fallback)
    let project_name = effective_project_name(manifest);
    if project_name.is_empty() {
        anyhow::bail!("project.name is required (or workload.name for legacy manifests)");
    }

    // Validate safety tier
    if SafetyTier::from_str_loose(&manifest.project.safety_tier).is_none() {
        anyhow::bail!(
            "Invalid safety-tier '{}'. Must be one of: kennel, yard, hunt",
            manifest.project.safety_tier
        );
    }

    // Validate each config entry
    for (i, cfg) in manifest.configs.iter().enumerate() {
        if cfg.name.is_empty() {
            anyhow::bail!("configs[{}].name is required", i);
        }
        if cfg.source.is_empty() {
            anyhow::bail!("configs[{}].source is required", i);
        }
        if ConfigFormat::from_str_loose(&cfg.format).is_none() {
            anyhow::bail!(
                "configs[{}].format '{}' is not recognised. Must be one of: toml, yaml, json, ini",
                i,
                cfg.format
            );
        }
    }

    // Validate report format
    let valid_report_formats = ["text", "json", "a2ml"];
    if !valid_report_formats.contains(&manifest.validation.report_format.as_str()) {
        anyhow::bail!(
            "Invalid report-format '{}'. Must be one of: text, json, a2ml",
            manifest.validation.report_format
        );
    }

    Ok(())
}

/// Get the effective project name, falling back to legacy workload.name.
pub fn effective_project_name(manifest: &Manifest) -> String {
    if !manifest.project.name.is_empty() {
        return manifest.project.name.clone();
    }
    if let Some(ref wl) = manifest.workload {
        return wl.name.clone();
    }
    String::new()
}

/// Initialise a new k9iser.toml manifest in the given directory.
///
/// Creates a K9-specific manifest with example config entry and all four
/// contract pillars populated with sensible defaults.
pub fn init_manifest(path: &str) -> Result<()> {
    let p = Path::new(path).join("k9iser.toml");
    if p.exists() {
        anyhow::bail!("k9iser.toml already exists at {}", p.display());
    }

    let template = r#"# k9iser manifest — wrap configs into self-validating K9 contracts
# SPDX-License-Identifier: PMPL-1.0-or-later

[project]
name = "my-config-project"
safety-tier = "kennel"           # kennel (low) | yard (medium) | hunt (high)

[[configs]]
name = "app-config"
source = "config/app.toml"      # config file to wrap
format = "toml"                  # toml | yaml | json | ini
# Contract pillars:
must = ["port > 0", "port < 65536", "host != ''"]
trust = ["signed-by: ci-pipeline"]
dust = ["remove: deprecated-keys"]
intend = ["production-ready"]

[validation]
strict = true                    # fail on any violation
auto-fix = false                 # auto-fix dust rules
report-format = "text"           # text | json | a2ml
"#;

    std::fs::write(&p, template)?;
    println!("Created {}", p.display());
    Ok(())
}

/// Print human-readable information about a manifest.
pub fn print_info(m: &Manifest) {
    let name = effective_project_name(m);
    let tier = &m.project.safety_tier;
    println!("=== {} ===", name);
    println!("Safety tier: {}", tier);
    println!("Configs: {}", m.configs.len());
    for cfg in &m.configs {
        println!("  - {} ({}) <- {}", cfg.name, cfg.format, cfg.source);
        println!("    must:   {:?}", cfg.must);
        println!("    trust:  {:?}", cfg.trust);
        println!("    dust:   {:?}", cfg.dust);
        println!("    intend: {:?}", cfg.intend);
    }
    println!(
        "Validation: strict={}, auto-fix={}, report={}",
        m.validation.strict, m.validation.auto_fix, m.validation.report_format
    );
}

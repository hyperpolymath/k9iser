// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// k9iser library — wraps configs into self-validating K9 contracts.
//
// Re-exports the three main modules:
// - abi: Rust types matching the Idris2 ABI (SafetyTier, K9Contract, etc.)
// - codegen: config parsing, contract generation, and validation
// - manifest: k9iser.toml manifest loading and validation

pub mod abi;
pub mod codegen;
pub mod manifest;

pub use manifest::{effective_project_name, load_manifest, validate, Manifest};

/// Generate K9 contracts from a manifest file.
///
/// Loads the manifest at `manifest_path`, validates it, then generates
/// .k9 contract files into `output_dir`.
pub fn generate(manifest_path: &str, output_dir: &str) -> anyhow::Result<()> {
    let m = load_manifest(manifest_path)?;
    validate(&m)?;
    codegen::generate_all(&m, output_dir)
}

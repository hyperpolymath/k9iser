// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// ABI module for k9iser — Rust types mirroring the Idris2 ABI definitions
// in src/interface/abi/Types.idr. These types represent the core K9 contract
// domain: safety tiers, contract pillars (must/trust/dust/intend), config
// formats, and validation results.

use serde::{Deserialize, Serialize};
use std::fmt;

/// Safety tier for a K9 contract project.
///
/// Maps to the Idris2 `SafetyTier` in Types.idr:
/// - Kennel: low-risk configs (dev, local)
/// - Yard: medium-risk configs (staging, internal)
/// - Hunt: high-risk configs (production, security-critical)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SafetyTier {
    Kennel,
    Yard,
    Hunt,
}

impl fmt::Display for SafetyTier {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            SafetyTier::Kennel => write!(f, "kennel"),
            SafetyTier::Yard => write!(f, "yard"),
            SafetyTier::Hunt => write!(f, "hunt"),
        }
    }
}

impl SafetyTier {
    /// Parse a safety tier from a string, case-insensitive.
    pub fn from_str_loose(s: &str) -> Option<SafetyTier> {
        match s.to_lowercase().as_str() {
            "kennel" => Some(SafetyTier::Kennel),
            "yard" => Some(SafetyTier::Yard),
            "hunt" => Some(SafetyTier::Hunt),
            _ => None,
        }
    }
}

/// Supported configuration file formats that k9iser can parse and wrap.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ConfigFormat {
    Toml,
    Yaml,
    Json,
    Ini,
}

impl fmt::Display for ConfigFormat {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ConfigFormat::Toml => write!(f, "toml"),
            ConfigFormat::Yaml => write!(f, "yaml"),
            ConfigFormat::Json => write!(f, "json"),
            ConfigFormat::Ini => write!(f, "ini"),
        }
    }
}

impl ConfigFormat {
    /// Parse a config format from a string, case-insensitive.
    pub fn from_str_loose(s: &str) -> Option<ConfigFormat> {
        match s.to_lowercase().as_str() {
            "toml" => Some(ConfigFormat::Toml),
            "yaml" | "yml" => Some(ConfigFormat::Yaml),
            "json" => Some(ConfigFormat::Json),
            "ini" => Some(ConfigFormat::Ini),
            _ => None,
        }
    }
}

/// A single "must" rule — a required constraint on a config key.
///
/// Must rules are parsed from strings like "port > 0" or "host != ''".
/// They encode the key name, comparison operator, and expected value.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MustRule {
    /// The config key this rule applies to (e.g. "port").
    pub key: String,
    /// The comparison operator (e.g. ">", "<", "!=", "==").
    pub operator: String,
    /// The value to compare against (e.g. "0", "65536", "''").
    pub value: String,
}

impl fmt::Display for MustRule {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{} {} {}", self.key, self.operator, self.value)
    }
}

/// A trust source declaration — identifies who/what must have signed or
/// verified the config for it to be considered trustworthy.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TrustSource {
    /// The trust type (e.g. "signed-by").
    pub trust_type: String,
    /// The trust source identifier (e.g. "ci-pipeline").
    pub source: String,
}

impl fmt::Display for TrustSource {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.trust_type, self.source)
    }
}

/// A dust rule — cleanup action to apply to configs (e.g. remove deprecated keys).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DustRule {
    /// The action to perform (e.g. "remove").
    pub action: String,
    /// The target of the action (e.g. "deprecated-keys").
    pub target: String,
}

impl fmt::Display for DustRule {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.action, self.target)
    }
}

/// An intent declaration — states the purpose or readiness level of the config.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct IntendDeclaration {
    /// The intent label (e.g. "production-ready").
    pub label: String,
}

impl fmt::Display for IntendDeclaration {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.label)
    }
}

/// A complete K9 contract comprising all four pillars for a single config entry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct K9Contract {
    /// Name of the config entry this contract covers.
    pub name: String,
    /// The source config file path.
    pub source: String,
    /// The format of the source config file.
    pub format: ConfigFormat,
    /// Safety tier inherited from the project.
    pub safety_tier: SafetyTier,
    /// Must rules — required constraints.
    pub must_rules: Vec<MustRule>,
    /// Trust sources — verified origins.
    pub trust_sources: Vec<TrustSource>,
    /// Dust rules — cleanup actions.
    pub dust_rules: Vec<DustRule>,
    /// Intend declarations — purpose statements.
    pub intend_declarations: Vec<IntendDeclaration>,
}

/// A single validation violation found when checking a config against its contract.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Violation {
    /// The rule that was violated (human-readable).
    pub rule: String,
    /// The config key involved, if applicable.
    pub key: Option<String>,
    /// Description of what went wrong.
    pub message: String,
}

impl fmt::Display for Violation {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match &self.key {
            Some(k) => write!(f, "[{}] {} (rule: {})", k, self.message, self.rule),
            None => write!(f, "{} (rule: {})", self.message, self.rule),
        }
    }
}

/// The result of validating a config against its K9 contract.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ValidationResult {
    /// All rules passed.
    Pass,
    /// One or more rules failed, with the list of violations.
    Fail(Vec<Violation>),
}

impl ValidationResult {
    /// Returns true if validation passed.
    pub fn is_pass(&self) -> bool {
        matches!(self, ValidationResult::Pass)
    }

    /// Returns the list of violations, or an empty slice if passed.
    pub fn violations(&self) -> &[Violation] {
        match self {
            ValidationResult::Pass => &[],
            ValidationResult::Fail(v) => v,
        }
    }
}

impl fmt::Display for ValidationResult {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ValidationResult::Pass => write!(f, "PASS"),
            ValidationResult::Fail(violations) => {
                writeln!(f, "FAIL ({} violation(s)):", violations.len())?;
                for v in violations {
                    writeln!(f, "  - {}", v)?;
                }
                Ok(())
            }
        }
    }
}

/// Parse a must-rule string like "port > 0" into a MustRule struct.
///
/// Supported operators: >, <, >=, <=, ==, !=
/// The format is: `key operator value`
pub fn parse_must_rule(rule_str: &str) -> Option<MustRule> {
    let rule_str = rule_str.trim();
    // Try two-char operators first, then single-char
    let operators = [">=", "<=", "!=", "==", ">", "<"];
    for op in &operators {
        if let Some(idx) = rule_str.find(op) {
            let key = rule_str[..idx].trim().to_string();
            let value = rule_str[idx + op.len()..].trim().to_string();
            if !key.is_empty() && !value.is_empty() {
                return Some(MustRule {
                    key,
                    operator: op.to_string(),
                    value,
                });
            }
        }
    }
    None
}

/// Parse a trust source string like "signed-by: ci-pipeline" into a TrustSource.
pub fn parse_trust_source(trust_str: &str) -> Option<TrustSource> {
    let parts: Vec<&str> = trust_str.splitn(2, ':').collect();
    if parts.len() == 2 {
        let trust_type = parts[0].trim().to_string();
        let source = parts[1].trim().to_string();
        if !trust_type.is_empty() && !source.is_empty() {
            return Some(TrustSource { trust_type, source });
        }
    }
    None
}

/// Parse a dust rule string like "remove: deprecated-keys" into a DustRule.
pub fn parse_dust_rule(dust_str: &str) -> Option<DustRule> {
    let parts: Vec<&str> = dust_str.splitn(2, ':').collect();
    if parts.len() == 2 {
        let action = parts[0].trim().to_string();
        let target = parts[1].trim().to_string();
        if !action.is_empty() && !target.is_empty() {
            return Some(DustRule { action, target });
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_must_rule_gt() {
        let rule = parse_must_rule("port > 0").unwrap();
        assert_eq!(rule.key, "port");
        assert_eq!(rule.operator, ">");
        assert_eq!(rule.value, "0");
    }

    #[test]
    fn test_parse_must_rule_lt() {
        let rule = parse_must_rule("port < 65536").unwrap();
        assert_eq!(rule.key, "port");
        assert_eq!(rule.operator, "<");
        assert_eq!(rule.value, "65536");
    }

    #[test]
    fn test_parse_must_rule_ne() {
        let rule = parse_must_rule("host != ''").unwrap();
        assert_eq!(rule.key, "host");
        assert_eq!(rule.operator, "!=");
        assert_eq!(rule.value, "''");
    }

    #[test]
    fn test_parse_trust_source() {
        let trust = parse_trust_source("signed-by: ci-pipeline").unwrap();
        assert_eq!(trust.trust_type, "signed-by");
        assert_eq!(trust.source, "ci-pipeline");
    }

    #[test]
    fn test_parse_dust_rule() {
        let dust = parse_dust_rule("remove: deprecated-keys").unwrap();
        assert_eq!(dust.action, "remove");
        assert_eq!(dust.target, "deprecated-keys");
    }

    #[test]
    fn test_safety_tier_display() {
        assert_eq!(SafetyTier::Kennel.to_string(), "kennel");
        assert_eq!(SafetyTier::Yard.to_string(), "yard");
        assert_eq!(SafetyTier::Hunt.to_string(), "hunt");
    }

    #[test]
    fn test_safety_tier_from_str() {
        assert_eq!(
            SafetyTier::from_str_loose("kennel"),
            Some(SafetyTier::Kennel)
        );
        assert_eq!(SafetyTier::from_str_loose("YARD"), Some(SafetyTier::Yard));
        assert_eq!(SafetyTier::from_str_loose("Hunt"), Some(SafetyTier::Hunt));
        assert_eq!(SafetyTier::from_str_loose("invalid"), None);
    }

    #[test]
    fn test_validation_result_pass() {
        let result = ValidationResult::Pass;
        assert!(result.is_pass());
        assert!(result.violations().is_empty());
    }

    #[test]
    fn test_validation_result_fail() {
        let result = ValidationResult::Fail(vec![Violation {
            rule: "port > 0".into(),
            key: Some("port".into()),
            message: "port is -1, expected > 0".into(),
        }]);
        assert!(!result.is_pass());
        assert_eq!(result.violations().len(), 1);
    }
}

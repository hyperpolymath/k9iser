// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// K9 contract generator for k9iser — produces .k9 contract files from
// parsed config structures and manifest rules. Also builds in-memory
// K9Contract structs for use by the validator.

use crate::abi::{
    ConfigFormat, IntendDeclaration, K9Contract, MustRule, SafetyTier, parse_dust_rule,
    parse_must_rule, parse_trust_source,
};
use crate::codegen::parser::{ParsedEntry, ValueType};

/// Generate a .k9 contract file as a string from manifest rules and parsed config entries.
///
/// The output format:
/// ```text
/// # Auto-generated K9 contract for <name>
/// # Safety tier: <tier>
///
/// [must]
/// key : type { constraint, ... }
///
/// [trust]
/// trust-type = "source"
///
/// [dust]
/// action = ["target"]
///
/// [intend]
/// label = true
/// ```
pub fn generate_k9_contract(
    name: &str,
    safety_tier: SafetyTier,
    must_rules: &[String],
    trust_sources: &[String],
    dust_rules: &[String],
    intend_declarations: &[String],
    parsed_entries: &[ParsedEntry],
) -> String {
    let mut output = String::new();

    // Header
    output.push_str(&format!("# Auto-generated K9 contract for {}\n", name));
    output.push_str(&format!("# Safety tier: {}\n", safety_tier));
    output.push('\n');

    // [must] section — group rules by key, augment with type info from parsed entries
    output.push_str("[must]\n");
    if must_rules.is_empty() {
        output.push_str("# (no must rules defined)\n");
    } else {
        // Group must rules by key
        let parsed_rules: Vec<MustRule> = must_rules
            .iter()
            .filter_map(|r| parse_must_rule(r))
            .collect();
        let mut keys_seen: Vec<String> = Vec::new();

        for rule in &parsed_rules {
            if !keys_seen.contains(&rule.key) {
                keys_seen.push(rule.key.clone());
            }
        }

        for key in &keys_seen {
            let key_rules: Vec<&MustRule> = parsed_rules.iter().filter(|r| &r.key == key).collect();

            // Infer type from parsed entries if available
            let type_str = infer_type_for_key(key, parsed_entries);

            let constraints: Vec<String> = key_rules
                .iter()
                .map(|r| format!("{} {}", r.operator, r.value))
                .collect();

            output.push_str(&format!(
                "{} : {} {{ {} }}\n",
                key,
                type_str,
                constraints.join(", ")
            ));
        }
    }
    output.push('\n');

    // [trust] section
    output.push_str("[trust]\n");
    if trust_sources.is_empty() {
        output.push_str("# (no trust sources defined)\n");
    } else {
        for ts in trust_sources {
            if let Some(parsed) = parse_trust_source(ts) {
                output.push_str(&format!("{} = \"{}\"\n", parsed.trust_type, parsed.source));
            }
        }
    }
    output.push('\n');

    // [dust] section
    output.push_str("[dust]\n");
    if dust_rules.is_empty() {
        output.push_str("# (no dust rules defined)\n");
    } else {
        // Group dust rules by action
        let parsed: Vec<_> = dust_rules
            .iter()
            .filter_map(|d| parse_dust_rule(d))
            .collect();
        let mut actions_seen: Vec<String> = Vec::new();
        for d in &parsed {
            if !actions_seen.contains(&d.action) {
                actions_seen.push(d.action.clone());
            }
        }
        for action in &actions_seen {
            let targets: Vec<String> = parsed
                .iter()
                .filter(|d| &d.action == action)
                .map(|d| format!("\"{}\"", d.target))
                .collect();
            output.push_str(&format!("{} = [{}]\n", action, targets.join(", ")));
        }
    }
    output.push('\n');

    // [intend] section
    output.push_str("[intend]\n");
    if intend_declarations.is_empty() {
        output.push_str("# (no intend declarations defined)\n");
    } else {
        for decl in intend_declarations {
            output.push_str(&format!("{} = true\n", decl));
        }
    }

    output
}

/// Build an in-memory K9Contract struct from manifest data.
///
/// This is used by the validator to check configs against contracts
/// without needing to read from a .k9 file.
pub fn build_k9_contract(
    name: &str,
    source: &str,
    format: ConfigFormat,
    safety_tier: SafetyTier,
    must_rules: &[String],
    trust_sources: &[String],
    dust_rules: &[String],
    intend_declarations: &[String],
) -> K9Contract {
    K9Contract {
        name: name.to_string(),
        source: source.to_string(),
        format,
        safety_tier,
        must_rules: must_rules
            .iter()
            .filter_map(|r| parse_must_rule(r))
            .collect(),
        trust_sources: trust_sources
            .iter()
            .filter_map(|t| parse_trust_source(t))
            .collect(),
        dust_rules: dust_rules
            .iter()
            .filter_map(|d| parse_dust_rule(d))
            .collect(),
        intend_declarations: intend_declarations
            .iter()
            .map(|label| IntendDeclaration {
                label: label.clone(),
            })
            .collect(),
    }
}

/// Infer the K9 type string for a key based on parsed config entries.
///
/// Falls back to "string" if the key is not found in parsed entries.
fn infer_type_for_key(key: &str, parsed_entries: &[ParsedEntry]) -> &'static str {
    // Try exact match first, then try matching the last segment
    let entry = parsed_entries
        .iter()
        .find(|e| e.key == key || e.key.ends_with(&format!(".{}", key)));

    match entry {
        Some(e) => match e.value_type {
            ValueType::Int => "int",
            ValueType::Float => "float",
            ValueType::String => "string",
            ValueType::Bool => "bool",
            ValueType::Array => "array",
            ValueType::Table => "table",
        },
        None => "string",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_k9_contract_basic() {
        let content = generate_k9_contract(
            "app-config",
            SafetyTier::Kennel,
            &[
                "port > 0".into(),
                "port < 65536".into(),
                "host != ''".into(),
            ],
            &["signed-by: ci-pipeline".into()],
            &["remove: deprecated-keys".into()],
            &["production-ready".into()],
            &[
                ParsedEntry {
                    key: "port".into(),
                    value: "8080".into(),
                    value_type: ValueType::Int,
                },
                ParsedEntry {
                    key: "host".into(),
                    value: "localhost".into(),
                    value_type: ValueType::String,
                },
            ],
        );

        assert!(content.contains("# Auto-generated K9 contract for app-config"));
        assert!(content.contains("# Safety tier: kennel"));
        assert!(content.contains("[must]"));
        assert!(content.contains("port : int { > 0, < 65536 }"));
        assert!(content.contains("host : string { != '' }"));
        assert!(content.contains("[trust]"));
        assert!(content.contains("signed-by = \"ci-pipeline\""));
        assert!(content.contains("[dust]"));
        assert!(content.contains("remove = [\"deprecated-keys\"]"));
        assert!(content.contains("[intend]"));
        assert!(content.contains("production-ready = true"));
    }

    #[test]
    fn test_build_k9_contract_struct() {
        let contract = build_k9_contract(
            "test",
            "config/test.toml",
            ConfigFormat::Toml,
            SafetyTier::Yard,
            &["port > 0".into()],
            &["signed-by: ci".into()],
            &["remove: old-keys".into()],
            &["staging".into()],
        );

        assert_eq!(contract.name, "test");
        assert_eq!(contract.safety_tier, SafetyTier::Yard);
        assert_eq!(contract.must_rules.len(), 1);
        assert_eq!(contract.trust_sources.len(), 1);
        assert_eq!(contract.dust_rules.len(), 1);
        assert_eq!(contract.intend_declarations.len(), 1);
    }
}

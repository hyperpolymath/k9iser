// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Config validator for k9iser — checks parsed config entries against K9
// contract must-rules and produces a ValidationResult with any violations.
//
// This validator handles numeric comparisons (>, <, >=, <=, ==, !=) for
// int/float values and string comparisons (==, !=) for string values.

use crate::abi::{K9Contract, MustRule, ValidationResult, Violation};
use crate::codegen::parser::{ParsedEntry, ValueType};

/// Validate a set of parsed config entries against a K9 contract.
///
/// Checks every must-rule in the contract against the parsed entries.
/// Returns Pass if all rules are satisfied, or Fail with the list of
/// violations.
pub fn validate_config(entries: &[ParsedEntry], contract: &K9Contract) -> ValidationResult {
    let mut violations = Vec::new();

    for rule in &contract.must_rules {
        // Find the matching config entry for this rule's key.
        // Try exact match first, then suffix match (e.g. "port" matches "server.port").
        let entry = entries
            .iter()
            .find(|e| e.key == rule.key || e.key.ends_with(&format!(".{}", rule.key)));

        match entry {
            None => {
                violations.push(Violation {
                    rule: rule.to_string(),
                    key: Some(rule.key.clone()),
                    message: format!("Key '{}' not found in config", rule.key),
                });
            }
            Some(entry) => {
                if let Some(violation) = check_must_rule(entry, rule) {
                    violations.push(violation);
                }
            }
        }
    }

    if violations.is_empty() {
        ValidationResult::Pass
    } else {
        ValidationResult::Fail(violations)
    }
}

/// Check a single must-rule against a parsed config entry.
///
/// Returns None if the rule is satisfied, or Some(Violation) if it is not.
fn check_must_rule(entry: &ParsedEntry, rule: &MustRule) -> Option<Violation> {
    match entry.value_type {
        ValueType::Int | ValueType::Float => check_numeric_rule(entry, rule),
        ValueType::String => check_string_rule(entry, rule),
        ValueType::Bool => check_string_rule(entry, rule),
        ValueType::Array | ValueType::Table => {
            // For complex types, only support != and == against string representation
            check_string_rule(entry, rule)
        }
    }
}

/// Check a numeric must-rule (>, <, >=, <=, ==, !=).
fn check_numeric_rule(entry: &ParsedEntry, rule: &MustRule) -> Option<Violation> {
    let actual: f64 = match entry.value.parse() {
        Ok(v) => v,
        Err(_) => {
            return Some(Violation {
                rule: rule.to_string(),
                key: Some(rule.key.clone()),
                message: format!(
                    "Cannot parse '{}' as number for numeric comparison",
                    entry.value
                ),
            });
        }
    };

    let expected: f64 = match rule.value.parse() {
        Ok(v) => v,
        Err(_) => {
            // If the rule value isn't numeric, fall back to string comparison
            return check_string_rule(entry, rule);
        }
    };

    let passed = match rule.operator.as_str() {
        ">" => actual > expected,
        "<" => actual < expected,
        ">=" => actual >= expected,
        "<=" => actual <= expected,
        "==" => (actual - expected).abs() < f64::EPSILON,
        "!=" => (actual - expected).abs() >= f64::EPSILON,
        _ => {
            return Some(Violation {
                rule: rule.to_string(),
                key: Some(rule.key.clone()),
                message: format!("Unknown operator '{}'", rule.operator),
            });
        }
    };

    if passed {
        None
    } else {
        Some(Violation {
            rule: rule.to_string(),
            key: Some(rule.key.clone()),
            message: format!(
                "Value {} does not satisfy {} {}",
                entry.value, rule.operator, rule.value
            ),
        })
    }
}

/// Check a string must-rule (==, !=).
///
/// For string comparisons, quoted values in the rule (e.g. '' or "") are
/// unquoted before comparing.
fn check_string_rule(entry: &ParsedEntry, rule: &MustRule) -> Option<Violation> {
    let actual = &entry.value;
    let expected = unquote_value(&rule.value);

    let passed = match rule.operator.as_str() {
        "==" => actual == &expected,
        "!=" => actual != &expected,
        ">" | "<" | ">=" | "<=" => {
            // For strings, compare lexicographically
            match rule.operator.as_str() {
                ">" => actual.as_str() > expected.as_str(),
                "<" => actual.as_str() < expected.as_str(),
                ">=" => actual.as_str() >= expected.as_str(),
                "<=" => actual.as_str() <= expected.as_str(),
                _ => unreachable!(),
            }
        }
        _ => {
            return Some(Violation {
                rule: rule.to_string(),
                key: Some(rule.key.clone()),
                message: format!("Unknown operator '{}'", rule.operator),
            });
        }
    };

    if passed {
        None
    } else {
        Some(Violation {
            rule: rule.to_string(),
            key: Some(rule.key.clone()),
            message: format!(
                "Value '{}' does not satisfy {} {}",
                actual, rule.operator, rule.value
            ),
        })
    }
}

/// Remove surrounding single or double quotes from a value string.
fn unquote_value(s: &str) -> String {
    if (s.starts_with('\'') && s.ends_with('\'')) || (s.starts_with('"') && s.ends_with('"')) {
        s[1..s.len() - 1].to_string()
    } else {
        s.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::abi::{ConfigFormat, SafetyTier};
    use crate::codegen::contract::build_k9_contract;

    #[test]
    fn test_validate_passing_config() {
        let entries = vec![
            ParsedEntry {
                key: "server.port".into(),
                value: "8080".into(),
                value_type: ValueType::Int,
            },
            ParsedEntry {
                key: "server.host".into(),
                value: "localhost".into(),
                value_type: ValueType::String,
            },
        ];

        let contract = build_k9_contract(
            "test",
            "config/test.toml",
            ConfigFormat::Toml,
            SafetyTier::Kennel,
            &[
                "port > 0".into(),
                "port < 65536".into(),
                "host != ''".into(),
            ],
            &[],
            &[],
            &[],
        );

        let result = validate_config(&entries, &contract);
        assert!(result.is_pass());
    }

    #[test]
    fn test_validate_failing_config() {
        let entries = vec![ParsedEntry {
            key: "port".into(),
            value: "-1".into(),
            value_type: ValueType::Int,
        }];

        let contract = build_k9_contract(
            "test",
            "config/test.toml",
            ConfigFormat::Toml,
            SafetyTier::Kennel,
            &["port > 0".into()],
            &[],
            &[],
            &[],
        );

        let result = validate_config(&entries, &contract);
        assert!(!result.is_pass());
        assert_eq!(result.violations().len(), 1);
    }

    #[test]
    fn test_validate_missing_key() {
        let entries = vec![]; // empty config

        let contract = build_k9_contract(
            "test",
            "config/test.toml",
            ConfigFormat::Toml,
            SafetyTier::Kennel,
            &["port > 0".into()],
            &[],
            &[],
            &[],
        );

        let result = validate_config(&entries, &contract);
        assert!(!result.is_pass());
        assert!(result.violations()[0].message.contains("not found"));
    }

    #[test]
    fn test_validate_string_not_empty() {
        let entries = vec![ParsedEntry {
            key: "host".into(),
            value: "".into(),
            value_type: ValueType::String,
        }];

        let contract = build_k9_contract(
            "test",
            "config/test.toml",
            ConfigFormat::Toml,
            SafetyTier::Kennel,
            &["host != ''".into()],
            &[],
            &[],
            &[],
        );

        let result = validate_config(&entries, &contract);
        assert!(!result.is_pass());
    }
}

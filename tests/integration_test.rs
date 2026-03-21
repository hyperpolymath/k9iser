// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Integration tests for k9iser — exercises manifest loading, validation,
// config parsing, contract generation, and rule checking end-to-end.

use k9iser::abi::{parse_must_rule, ConfigFormat, SafetyTier};
use k9iser::codegen::contract::build_k9_contract;
use k9iser::codegen::parser::{parse_config_string, ParsedEntry, ValueType};
use k9iser::codegen::validator::validate_config;
use k9iser::manifest;
use tempfile::TempDir;

/// Test that `init_manifest` creates a valid k9iser.toml file with the
/// expected K9-specific schema (project, configs, validation sections).
#[test]
fn test_init_creates_manifest() {
    let dir = TempDir::new().unwrap();
    let path = dir.path().to_str().unwrap();

    manifest::init_manifest(path).unwrap();

    let manifest_path = dir.path().join("k9iser.toml");
    assert!(manifest_path.exists(), "k9iser.toml should be created");

    let content = std::fs::read_to_string(&manifest_path).unwrap();
    assert!(content.contains("[project]"), "Should have [project] section");
    assert!(content.contains("safety-tier"), "Should have safety-tier field");
    assert!(content.contains("[[configs]]"), "Should have [[configs]] section");
    assert!(content.contains("[validation]"), "Should have [validation] section");
    assert!(content.contains("must"), "Should have must pillar");
    assert!(content.contains("trust"), "Should have trust pillar");
    assert!(content.contains("dust"), "Should have dust pillar");
    assert!(content.contains("intend"), "Should have intend pillar");
}

/// Test that a valid manifest loads and validates without error, and that
/// all fields are correctly deserialised.
#[test]
fn test_load_and_validate_manifest() {
    let dir = TempDir::new().unwrap();
    let path = dir.path().to_str().unwrap();

    manifest::init_manifest(path).unwrap();

    let manifest_path = dir.path().join("k9iser.toml");
    let m = manifest::load_manifest(manifest_path.to_str().unwrap()).unwrap();

    // Validate should pass
    manifest::validate(&m).unwrap();

    // Check deserialized fields
    assert_eq!(m.project.name, "my-config-project");
    assert_eq!(m.project.safety_tier, "kennel");
    assert_eq!(m.configs.len(), 1);
    assert_eq!(m.configs[0].name, "app-config");
    assert_eq!(m.configs[0].format, "toml");
    assert!(!m.configs[0].must.is_empty());
    assert!(m.validation.strict);
}

/// Test that a manifest with an empty project name is rejected.
#[test]
fn test_validate_rejects_empty_name() {
    let dir = TempDir::new().unwrap();
    let manifest_content = r#"
[project]
name = ""
safety-tier = "kennel"

[validation]
strict = true
"#;
    let path = dir.path().join("k9iser.toml");
    std::fs::write(&path, manifest_content).unwrap();

    let m = manifest::load_manifest(path.to_str().unwrap()).unwrap();
    let result = manifest::validate(&m);
    assert!(result.is_err(), "Empty name should be rejected");
    assert!(
        result.unwrap_err().to_string().contains("name"),
        "Error should mention name"
    );
}

/// Test that generate produces .k9 contract files for each config entry.
#[test]
fn test_generate_produces_k9_contracts() {
    let dir = TempDir::new().unwrap();

    // Create a config file
    let config_dir = dir.path().join("config");
    std::fs::create_dir_all(&config_dir).unwrap();
    std::fs::write(
        config_dir.join("app.toml"),
        "[server]\nport = 8080\nhost = \"localhost\"\n",
    )
    .unwrap();

    // Create manifest
    let manifest_content = r#"
[project]
name = "test-project"
safety-tier = "kennel"

[[configs]]
name = "app-config"
source = "config/app.toml"
format = "toml"
must = ["port > 0", "port < 65536", "host != ''"]
trust = ["signed-by: ci-pipeline"]
dust = ["remove: deprecated-keys"]
intend = ["production-ready"]

[validation]
strict = true
"#;
    let manifest_path = dir.path().join("k9iser.toml");
    std::fs::write(&manifest_path, manifest_content).unwrap();

    let m = manifest::load_manifest(manifest_path.to_str().unwrap()).unwrap();

    let output_dir = dir.path().join("generated");
    // Change to temp dir so relative source paths resolve
    let original_dir = std::env::current_dir().unwrap();
    std::env::set_current_dir(dir.path()).unwrap();

    let result = k9iser::codegen::generate_all(&m, output_dir.to_str().unwrap());
    std::env::set_current_dir(&original_dir).unwrap();

    assert!(result.is_ok(), "Generation should succeed: {:?}", result);

    let contract_file = output_dir.join("app-config.k9");
    assert!(contract_file.exists(), ".k9 contract file should exist");

    let content = std::fs::read_to_string(&contract_file).unwrap();
    assert!(content.contains("[must]"));
    assert!(content.contains("port : int"));
    assert!(content.contains("[trust]"));
    assert!(content.contains("[dust]"));
    assert!(content.contains("[intend]"));
}

/// Test that the validator correctly validates configs against contracts.
#[test]
fn test_generate_produces_validator() {
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
        &["signed-by: ci".into()],
        &["remove: old-keys".into()],
        &["staging".into()],
    );

    let result = validate_config(&entries, &contract);
    assert!(result.is_pass(), "Valid config should pass: {}", result);

    // Now test with an invalid port
    let bad_entries = vec![ParsedEntry {
        key: "port".into(),
        value: "-5".into(),
        value_type: ValueType::Int,
    }];

    let bad_result = validate_config(&bad_entries, &contract);
    assert!(
        !bad_result.is_pass(),
        "Invalid config should fail validation"
    );
}

/// Test must-rule parsing covers all supported operators.
#[test]
fn test_must_rule_parsing() {
    let cases = vec![
        ("port > 0", "port", ">", "0"),
        ("port < 65536", "port", "<", "65536"),
        ("count >= 1", "count", ">=", "1"),
        ("timeout <= 30", "timeout", "<=", "30"),
        ("mode == 'production'", "mode", "==", "'production'"),
        ("host != ''", "host", "!=", "''"),
    ];

    for (input, expected_key, expected_op, expected_val) in cases {
        let rule = parse_must_rule(input);
        assert!(rule.is_some(), "Should parse: {}", input);
        let rule = rule.unwrap();
        assert_eq!(rule.key, expected_key, "Key mismatch for: {}", input);
        assert_eq!(rule.operator, expected_op, "Operator mismatch for: {}", input);
        assert_eq!(rule.value, expected_val, "Value mismatch for: {}", input);
    }
}

/// Test TOML config parsing extracts correct key-value pairs with types.
#[test]
fn test_toml_config_parsing() {
    let content = r#"
[server]
port = 8080
host = "localhost"
debug = false
weight = 1.5

[database]
url = "postgres://localhost/mydb"
pool-size = 10
"#;

    let entries = parse_config_string(content, ConfigFormat::Toml).unwrap();

    // Check server.port
    let port = entries.iter().find(|e| e.key == "server.port").unwrap();
    assert_eq!(port.value, "8080");
    assert_eq!(port.value_type, ValueType::Int);

    // Check server.host
    let host = entries.iter().find(|e| e.key == "server.host").unwrap();
    assert_eq!(host.value, "localhost");
    assert_eq!(host.value_type, ValueType::String);

    // Check server.debug
    let debug = entries.iter().find(|e| e.key == "server.debug").unwrap();
    assert_eq!(debug.value, "false");
    assert_eq!(debug.value_type, ValueType::Bool);

    // Check server.weight
    let weight = entries.iter().find(|e| e.key == "server.weight").unwrap();
    assert_eq!(weight.value, "1.5");
    assert_eq!(weight.value_type, ValueType::Float);

    // Check database.pool-size
    let pool = entries.iter().find(|e| e.key == "database.pool-size").unwrap();
    assert_eq!(pool.value, "10");
    assert_eq!(pool.value_type, ValueType::Int);
}

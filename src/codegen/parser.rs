// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Config file parser for k9iser — reads TOML, YAML, JSON, and INI config
// files and extracts their key-value structure into a flat list of
// ParsedEntry items. This flattened representation is used by the contract
// generator and validator to check must-rules against actual config values.

use anyhow::{Context, Result};

use crate::abi::ConfigFormat;

/// A single parsed key-value entry from a config file.
///
/// Keys are flattened using dot notation for nested structures.
/// For example, `[server]\nport = 8080` becomes `ParsedEntry { key: "server.port", value: "8080", value_type: Int }`.
#[derive(Debug, Clone, PartialEq)]
pub struct ParsedEntry {
    /// Dot-separated key path (e.g. "server.port", "database.host").
    pub key: String,
    /// String representation of the value.
    pub value: String,
    /// Inferred type of the value.
    pub value_type: ValueType,
}

/// Inferred type of a parsed config value, used for type-aware constraint checking.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ValueType {
    /// An integer value (i64 range).
    Int,
    /// A floating-point value.
    Float,
    /// A string value.
    String,
    /// A boolean value.
    Bool,
    /// An array (serialised as string).
    Array,
    /// A table/object (serialised as string).
    Table,
}

/// Parse a config file at the given path, returning a flat list of key-value entries.
///
/// The file format is determined by the `format` parameter, not by file extension.
pub fn parse_config_file(path: &str, format: ConfigFormat) -> Result<Vec<ParsedEntry>> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("Failed to read config: {}", path))?;
    parse_config_string(&content, format)
}

/// Parse a config string in the given format, returning a flat list of key-value entries.
pub fn parse_config_string(content: &str, format: ConfigFormat) -> Result<Vec<ParsedEntry>> {
    match format {
        ConfigFormat::Toml => parse_toml(content),
        ConfigFormat::Json => parse_json(content),
        ConfigFormat::Yaml => parse_yaml(content),
        ConfigFormat::Ini => parse_ini(content),
    }
}

// ---------------------------------------------------------------------------
// TOML parser — uses the `toml` crate already in dependencies
// ---------------------------------------------------------------------------

/// Parse TOML content into flat key-value entries.
fn parse_toml(content: &str) -> Result<Vec<ParsedEntry>> {
    let table: toml::Table = content
        .parse()
        .with_context(|| "Failed to parse TOML content")?;
    let mut entries = Vec::new();
    flatten_toml_value(&toml::Value::Table(table), "", &mut entries);
    Ok(entries)
}

/// Recursively flatten a TOML value tree into dot-separated key-value entries.
fn flatten_toml_value(value: &toml::Value, prefix: &str, entries: &mut Vec<ParsedEntry>) {
    match value {
        toml::Value::Table(table) => {
            for (key, val) in table {
                let full_key = if prefix.is_empty() {
                    key.clone()
                } else {
                    format!("{}.{}", prefix, key)
                };
                flatten_toml_value(val, &full_key, entries);
            }
        }
        toml::Value::Array(arr) => {
            entries.push(ParsedEntry {
                key: prefix.to_string(),
                value: format!("{:?}", arr),
                value_type: ValueType::Array,
            });
        }
        toml::Value::String(s) => {
            entries.push(ParsedEntry {
                key: prefix.to_string(),
                value: s.clone(),
                value_type: ValueType::String,
            });
        }
        toml::Value::Integer(i) => {
            entries.push(ParsedEntry {
                key: prefix.to_string(),
                value: i.to_string(),
                value_type: ValueType::Int,
            });
        }
        toml::Value::Float(f) => {
            entries.push(ParsedEntry {
                key: prefix.to_string(),
                value: f.to_string(),
                value_type: ValueType::Float,
            });
        }
        toml::Value::Boolean(b) => {
            entries.push(ParsedEntry {
                key: prefix.to_string(),
                value: b.to_string(),
                value_type: ValueType::Bool,
            });
        }
        toml::Value::Datetime(dt) => {
            entries.push(ParsedEntry {
                key: prefix.to_string(),
                value: dt.to_string(),
                value_type: ValueType::String,
            });
        }
    }
}

// ---------------------------------------------------------------------------
// JSON parser — manual recursive descent using serde_json via toml's serde
// ---------------------------------------------------------------------------

/// Parse JSON content into flat key-value entries.
///
/// We use a lightweight approach: parse JSON manually to avoid adding
/// serde_json as a dependency. JSON is structurally similar to TOML tables,
/// so we convert via a simple recursive parser.
fn parse_json(content: &str) -> Result<Vec<ParsedEntry>> {
    // Parse JSON using a minimal approach: convert to toml::Value via serde
    // Since we already have serde + toml, we deserialize JSON manually.
    let json_value: JsonValue =
        parse_json_value(content.trim()).with_context(|| "Failed to parse JSON content")?;
    let mut entries = Vec::new();
    flatten_json_value(&json_value, "", &mut entries);
    Ok(entries)
}

/// Minimal JSON value representation for parsing without serde_json dependency.
#[derive(Debug, Clone)]
enum JsonValue {
    Null,
    Bool(bool),
    Number(f64),
    Str(String),
    Array(Vec<JsonValue>),
    Object(Vec<(String, JsonValue)>),
}

/// Minimal recursive descent JSON parser.
fn parse_json_value(input: &str) -> Result<JsonValue> {
    let input = input.trim();
    if input.is_empty() {
        anyhow::bail!("Empty JSON input");
    }

    match input.as_bytes()[0] {
        b'{' => parse_json_object(input),
        b'[' => parse_json_array(input),
        b'"' => parse_json_string(input).map(|(s, _)| JsonValue::Str(s)),
        b't' if input.starts_with("true") => Ok(JsonValue::Bool(true)),
        b'f' if input.starts_with("false") => Ok(JsonValue::Bool(false)),
        b'n' if input.starts_with("null") => Ok(JsonValue::Null),
        _ => {
            // Try to parse as number
            let end = input
                .find(|c: char| {
                    !c.is_ascii_digit() && c != '.' && c != '-' && c != '+' && c != 'e' && c != 'E'
                })
                .unwrap_or(input.len());
            let num_str = &input[..end];
            let num: f64 = num_str
                .parse()
                .with_context(|| format!("Invalid JSON number: {}", num_str))?;
            Ok(JsonValue::Number(num))
        }
    }
}

/// Parse a JSON object: { "key": value, ... }
fn parse_json_object(input: &str) -> Result<JsonValue> {
    let inner = find_matching_brace(input, b'{', b'}')?;
    let inner = inner.trim();
    if inner.is_empty() {
        return Ok(JsonValue::Object(Vec::new()));
    }

    let mut entries = Vec::new();
    let mut rest = inner;

    while !rest.trim().is_empty() {
        rest = rest.trim();
        // Parse key
        let (key, after_key) = parse_json_string(rest)?;
        let after_key = after_key.trim();
        // Expect colon
        if !after_key.starts_with(':') {
            anyhow::bail!("Expected ':' after key in JSON object");
        }
        let value_str = after_key[1..].trim();
        // Parse value — need to find where it ends
        let (value, after_value) = parse_json_value_with_rest(value_str)?;
        entries.push((key, value));
        let after_value = after_value.trim();
        if after_value.starts_with(',') {
            rest = &after_value[1..];
        } else {
            break;
        }
    }

    Ok(JsonValue::Object(entries))
}

/// Parse a JSON array: [ value, ... ]
fn parse_json_array(input: &str) -> Result<JsonValue> {
    let inner = find_matching_brace(input, b'[', b']')?;
    let inner = inner.trim();
    if inner.is_empty() {
        return Ok(JsonValue::Array(Vec::new()));
    }

    let mut items = Vec::new();
    let mut rest = inner;

    while !rest.trim().is_empty() {
        rest = rest.trim();
        let (value, after_value) = parse_json_value_with_rest(rest)?;
        items.push(value);
        let after_value = after_value.trim();
        if after_value.starts_with(',') {
            rest = &after_value[1..];
        } else {
            break;
        }
    }

    Ok(JsonValue::Array(items))
}

/// Parse a JSON string, returning the string contents and the remaining input.
fn parse_json_string(input: &str) -> Result<(String, &str)> {
    let input = input.trim();
    if !input.starts_with('"') {
        anyhow::bail!("Expected '\"' at start of JSON string");
    }
    let bytes = input.as_bytes();
    let mut i = 1;
    let mut result = String::new();
    while i < bytes.len() {
        if bytes[i] == b'\\' && i + 1 < bytes.len() {
            match bytes[i + 1] {
                b'"' => {
                    result.push('"');
                    i += 2;
                }
                b'\\' => {
                    result.push('\\');
                    i += 2;
                }
                b'n' => {
                    result.push('\n');
                    i += 2;
                }
                b't' => {
                    result.push('\t');
                    i += 2;
                }
                b'r' => {
                    result.push('\r');
                    i += 2;
                }
                b'/' => {
                    result.push('/');
                    i += 2;
                }
                _ => {
                    result.push(bytes[i + 1] as char);
                    i += 2;
                }
            }
        } else if bytes[i] == b'"' {
            return Ok((result, &input[i + 1..]));
        } else {
            result.push(bytes[i] as char);
            i += 1;
        }
    }
    anyhow::bail!("Unterminated JSON string");
}

/// Parse a JSON value and return remaining input.
fn parse_json_value_with_rest(input: &str) -> Result<(JsonValue, &str)> {
    let input = input.trim();
    if input.is_empty() {
        anyhow::bail!("Unexpected end of JSON input");
    }

    match input.as_bytes()[0] {
        b'{' => {
            let end = find_matching_brace_end(input, b'{', b'}')?;
            let val = parse_json_object(&input[..end])?;
            Ok((val, &input[end..]))
        }
        b'[' => {
            let end = find_matching_brace_end(input, b'[', b']')?;
            let val = parse_json_array(&input[..end])?;
            Ok((val, &input[end..]))
        }
        b'"' => {
            let (s, rest) = parse_json_string(input)?;
            Ok((JsonValue::Str(s), rest))
        }
        b't' if input.starts_with("true") => Ok((JsonValue::Bool(true), &input[4..])),
        b'f' if input.starts_with("false") => Ok((JsonValue::Bool(false), &input[5..])),
        b'n' if input.starts_with("null") => Ok((JsonValue::Null, &input[4..])),
        _ => {
            let end = input
                .find(|c: char| {
                    !c.is_ascii_digit() && c != '.' && c != '-' && c != '+' && c != 'e' && c != 'E'
                })
                .unwrap_or(input.len());
            let num_str = &input[..end];
            let num: f64 = num_str
                .parse()
                .with_context(|| format!("Invalid JSON number: {}", num_str))?;
            Ok((JsonValue::Number(num), &input[end..]))
        }
    }
}

/// Find the content between matching braces, returning the inner content.
fn find_matching_brace(input: &str, open: u8, close: u8) -> Result<&str> {
    let end = find_matching_brace_end(input, open, close)?;
    // Return inner content (skip opening and closing braces)
    Ok(&input[1..end - 1])
}

/// Find the position just after the matching close brace.
fn find_matching_brace_end(input: &str, open: u8, close: u8) -> Result<usize> {
    let bytes = input.as_bytes();
    let mut depth = 0;
    let mut in_string = false;
    let mut i = 0;
    while i < bytes.len() {
        if in_string {
            if bytes[i] == b'\\' {
                i += 1; // skip escaped char
            } else if bytes[i] == b'"' {
                in_string = false;
            }
        } else {
            if bytes[i] == b'"' {
                in_string = true;
            } else if bytes[i] == open {
                depth += 1;
            } else if bytes[i] == close {
                depth -= 1;
                if depth == 0 {
                    return Ok(i + 1);
                }
            }
        }
        i += 1;
    }
    anyhow::bail!("Unmatched brace in JSON input");
}

/// Flatten a JSON value tree into dot-separated key-value entries.
fn flatten_json_value(value: &JsonValue, prefix: &str, entries: &mut Vec<ParsedEntry>) {
    match value {
        JsonValue::Object(obj) => {
            for (key, val) in obj {
                let full_key = if prefix.is_empty() {
                    key.clone()
                } else {
                    format!("{}.{}", prefix, key)
                };
                flatten_json_value(val, &full_key, entries);
            }
        }
        JsonValue::Array(arr) => {
            entries.push(ParsedEntry {
                key: prefix.to_string(),
                value: format!("{:?}", arr),
                value_type: ValueType::Array,
            });
        }
        JsonValue::Str(s) => {
            entries.push(ParsedEntry {
                key: prefix.to_string(),
                value: s.clone(),
                value_type: ValueType::String,
            });
        }
        JsonValue::Number(n) => {
            // Distinguish int vs float
            if n.fract() == 0.0 && *n >= i64::MIN as f64 && *n <= i64::MAX as f64 {
                entries.push(ParsedEntry {
                    key: prefix.to_string(),
                    value: (*n as i64).to_string(),
                    value_type: ValueType::Int,
                });
            } else {
                entries.push(ParsedEntry {
                    key: prefix.to_string(),
                    value: n.to_string(),
                    value_type: ValueType::Float,
                });
            }
        }
        JsonValue::Bool(b) => {
            entries.push(ParsedEntry {
                key: prefix.to_string(),
                value: b.to_string(),
                value_type: ValueType::Bool,
            });
        }
        JsonValue::Null => {
            entries.push(ParsedEntry {
                key: prefix.to_string(),
                value: "null".to_string(),
                value_type: ValueType::String,
            });
        }
    }
}

// ---------------------------------------------------------------------------
// YAML parser — lightweight line-based parser (no serde_yaml dependency)
// ---------------------------------------------------------------------------

/// Parse YAML content into flat key-value entries.
///
/// This is a lightweight parser handling common YAML patterns:
/// - key: value pairs
/// - nested keys via indentation
/// Does NOT handle anchors, aliases, multiline strings, or flow style.
fn parse_yaml(content: &str) -> Result<Vec<ParsedEntry>> {
    let mut entries = Vec::new();
    // Stack of (indent_level, key_prefix) for tracking nesting
    let mut stack: Vec<(usize, String)> = Vec::new();

    for line in content.lines() {
        let trimmed = line.trim();
        // Skip empty lines and comments
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        // Skip YAML document markers
        if trimmed == "---" || trimmed == "..." {
            continue;
        }

        let indent = line.len() - line.trim_start().len();

        // Pop stack entries that are at the same or deeper indent
        while let Some(&(level, _)) = stack.last() {
            if level >= indent {
                stack.pop();
            } else {
                break;
            }
        }

        // Parse key: value
        if let Some(colon_pos) = trimmed.find(':') {
            let key = trimmed[..colon_pos].trim().to_string();
            let value_part = trimmed[colon_pos + 1..].trim();

            let prefix = stack
                .last()
                .map(|(_, p)| format!("{}.{}", p, key))
                .unwrap_or_else(|| key.clone());

            if value_part.is_empty() {
                // This is a section header — push onto stack
                stack.push((indent, prefix));
            } else {
                // This is a leaf value
                let (value, value_type) = classify_yaml_value(value_part);
                entries.push(ParsedEntry {
                    key: prefix,
                    value,
                    value_type,
                });
            }
        }
    }

    Ok(entries)
}

/// Classify a YAML value string into a typed ParsedEntry value.
fn classify_yaml_value(s: &str) -> (String, ValueType) {
    // Boolean
    match s.to_lowercase().as_str() {
        "true" | "yes" | "on" => return ("true".to_string(), ValueType::Bool),
        "false" | "no" | "off" => return ("false".to_string(), ValueType::Bool),
        "null" | "~" => return ("null".to_string(), ValueType::String),
        _ => {}
    }

    // Quoted string — remove quotes
    if (s.starts_with('"') && s.ends_with('"')) || (s.starts_with('\'') && s.ends_with('\'')) {
        return (s[1..s.len() - 1].to_string(), ValueType::String);
    }

    // Integer
    if s.parse::<i64>().is_ok() {
        return (s.to_string(), ValueType::Int);
    }

    // Float
    if s.parse::<f64>().is_ok() {
        return (s.to_string(), ValueType::Float);
    }

    // Default to string
    (s.to_string(), ValueType::String)
}

// ---------------------------------------------------------------------------
// INI parser — simple line-based parser for .ini / .cfg files
// ---------------------------------------------------------------------------

/// Parse INI content into flat key-value entries.
///
/// Handles:
/// - [section] headers
/// - key = value pairs
/// - Comments starting with ; or #
fn parse_ini(content: &str) -> Result<Vec<ParsedEntry>> {
    let mut entries = Vec::new();
    let mut current_section = String::new();

    for line in content.lines() {
        let trimmed = line.trim();
        // Skip empty lines and comments
        if trimmed.is_empty() || trimmed.starts_with(';') || trimmed.starts_with('#') {
            continue;
        }

        // Section header
        if trimmed.starts_with('[') && trimmed.ends_with(']') {
            current_section = trimmed[1..trimmed.len() - 1].trim().to_string();
            continue;
        }

        // Key = value pair
        if let Some(eq_pos) = trimmed.find('=') {
            let key = trimmed[..eq_pos].trim().to_string();
            let raw_value = trimmed[eq_pos + 1..].trim().to_string();

            let full_key = if current_section.is_empty() {
                key
            } else {
                format!("{}.{}", current_section, key)
            };

            let (value, value_type) = classify_ini_value(&raw_value);
            entries.push(ParsedEntry {
                key: full_key,
                value,
                value_type,
            });
        }
    }

    Ok(entries)
}

/// Classify an INI value string into a typed value.
fn classify_ini_value(s: &str) -> (String, ValueType) {
    // Strip inline comments
    let s = if let Some(pos) = s.find(';') {
        s[..pos].trim()
    } else {
        s
    };

    // Boolean
    match s.to_lowercase().as_str() {
        "true" | "yes" | "on" => return ("true".to_string(), ValueType::Bool),
        "false" | "no" | "off" => return ("false".to_string(), ValueType::Bool),
        _ => {}
    }

    // Integer
    if s.parse::<i64>().is_ok() {
        return (s.to_string(), ValueType::Int);
    }

    // Float
    if s.parse::<f64>().is_ok() {
        return (s.to_string(), ValueType::Float);
    }

    // Default to string
    (s.to_string(), ValueType::String)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_toml_simple() {
        let content = r#"
[server]
port = 8080
host = "localhost"
debug = true
"#;
        let entries = parse_toml(content).unwrap();
        assert!(entries.iter().any(|e| e.key == "server.port"
            && e.value == "8080"
            && e.value_type == ValueType::Int));
        assert!(entries.iter().any(|e| e.key == "server.host"
            && e.value == "localhost"
            && e.value_type == ValueType::String));
        assert!(entries.iter().any(|e| e.key == "server.debug"
            && e.value == "true"
            && e.value_type == ValueType::Bool));
    }

    #[test]
    fn test_parse_json_simple() {
        let content = r#"{"port": 8080, "host": "localhost", "debug": true}"#;
        let entries = parse_json(content).unwrap();
        assert!(
            entries
                .iter()
                .any(|e| e.key == "port" && e.value == "8080" && e.value_type == ValueType::Int)
        );
        assert!(entries.iter().any(|e| e.key == "host"
            && e.value == "localhost"
            && e.value_type == ValueType::String));
        assert!(
            entries
                .iter()
                .any(|e| e.key == "debug" && e.value == "true" && e.value_type == ValueType::Bool)
        );
    }

    #[test]
    fn test_parse_yaml_simple() {
        let content = "server:\n  port: 8080\n  host: localhost\n  debug: true\n";
        let entries = parse_yaml(content).unwrap();
        assert!(entries.iter().any(|e| e.key == "server.port"
            && e.value == "8080"
            && e.value_type == ValueType::Int));
        assert!(entries.iter().any(|e| e.key == "server.host"
            && e.value == "localhost"
            && e.value_type == ValueType::String));
        assert!(entries.iter().any(|e| e.key == "server.debug"
            && e.value == "true"
            && e.value_type == ValueType::Bool));
    }

    #[test]
    fn test_parse_ini_simple() {
        let content = "[server]\nport = 8080\nhost = localhost\ndebug = true\n";
        let entries = parse_ini(content).unwrap();
        assert!(entries.iter().any(|e| e.key == "server.port"
            && e.value == "8080"
            && e.value_type == ValueType::Int));
        assert!(entries.iter().any(|e| e.key == "server.host"
            && e.value == "localhost"
            && e.value_type == ValueType::String));
        assert!(entries.iter().any(|e| e.key == "server.debug"
            && e.value == "true"
            && e.value_type == ValueType::Bool));
    }
}

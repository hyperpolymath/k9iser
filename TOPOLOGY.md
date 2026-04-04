<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->
# TOPOLOGY.md — k9iser

## Purpose

k9iser wraps configuration files and deployment definitions into self-validating K9 contracts. It reads existing configs (TOML, YAML, JSON, etc.) and generates `.k9` contract files that encode the expected structure, permitted values, and invariants of those configs. Engineers use k9iser to prevent configuration drift, enforce deployment contracts, and confirm that all config changes satisfy their stated constraints before rollout.

## Module Map

```
k9iser/
├── src/
│   ├── main.rs                    # CLI entry point (clap): init, validate, generate, build, run, info
│   ├── lib.rs                     # Library API
│   ├── manifest/mod.rs            # k9iser.toml parser
│   ├── codegen/mod.rs             # .k9 contract file generation
│   └── abi/                       # Idris2 ABI bridge stubs
├── examples/                      # Worked examples
├── verification/                  # Proof harnesses
├── container/                     # Stapeln container ecosystem
└── .machine_readable/             # A2ML metadata
```

## Data Flow

```
k9iser.toml manifest
        │
   ┌────▼────┐
   │ Manifest │  parse + validate contract pillar definitions
   │  Parser  │
   └────┬────┘
        │  validated contract config
   ┌────▼────┐
   │ Analyser │  read source config files, infer schema
   └────┬────┘
        │  intermediate representation
   ┌────▼────┐
   │ Codegen  │  emit generated/k9iser/ (.k9 contract files)
   └────┬────┘
        │  .k9 contracts
   ┌────▼────┐
   │ Validator│  confirm configs satisfy all K9 contract pillars
   └─────────┘
```

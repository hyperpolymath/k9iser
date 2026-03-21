<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->
# k9iser Topology

## Module Map

```
k9iser
├── CLI Layer (Rust)
│   ├── main.rs          ─── clap CLI entry point
│   ├── lib.rs           ─── library API surface
│   ├── manifest/        ─── k9iser.toml parser (serde + toml)
│   └── codegen/         ─── K9 contract code generation orchestration
│
├── Domain Core (Rust)
│   ├── core/            ─── constraint inference engine, validation engine
│   ├── contracts/       ─── K9 contract data model (MustRule, TrustSource, etc.)
│   ├── definitions/     ─── built-in constraint definitions
│   ├── errors/          ─── structured error types (thiserror)
│   ├── bridges/         ─── format-specific config parsers
│   │   ├── toml         ─── TOML config analysis
│   │   ├── yaml         ─── YAML config analysis
│   │   ├── json         ─── JSON config analysis
│   │   └── nickel       ─── Nickel config analysis
│   └── aspects/         ─── cross-cutting concerns (logging, attestation)
│
├── Verified Interface (Idris2 ABI + Zig FFI)
│   ├── interface/abi/
│   │   ├── Types.idr    ─── K9Contract, Constraint, MustRule, TrustSource,
│   │   │                    DustRule, IntendDeclaration, ValidationResult,
│   │   │                    SafetyTier, ConfigFormat, Result
│   │   ├── Layout.idr   ─── struct layout proofs for K9Contract,
│   │   │                    ValidationResult, MustRule (C ABI compliance)
│   │   └── Foreign.idr  ─── FFI declarations: config parsing, constraint
│   │                        inference, contract generation, validation,
│   │                        attestation
│   ├── interface/ffi/
│   │   ├── build.zig    ─── shared + static library build
│   │   ├── src/main.zig ─── C-ABI implementation of Foreign.idr declarations
│   │   └── test/        ─── integration tests verifying ABI conformance
│   └── interface/generated/
│       └── abi/         ─── auto-generated C headers (from Idris2 ABI)
│
└── Contractiles (K9 Templates)
    └── .machine_readable/contractiles/k9/
        ├── template-kennel.k9.ncl  ─── Kennel tier contract template
        ├── template-yard.k9.ncl    ─── Yard tier contract template
        ├── template-hunt.k9.ncl    ─── Hunt tier contract template
        ├── validators/             ─── K9 validator implementations
        └── examples/               ─── example contracts for real configs
```

## Data Flow

```
                  ┌─────────────┐
                  │ Config File │  (TOML / YAML / JSON / Nickel)
                  └──────┬──────┘
                         │
                    ┌────▼────┐
                    │ bridges │  format-specific parser
                    └────┬────┘
                         │
                 ┌───────▼───────┐
                 │   core/infer  │  constraint inference engine
                 └───────┬───────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
     ┌────────┐   ┌───────────┐   ┌─────────┐
     │  must  │   │   trust   │   │  dust/   │
     │ rules  │   │  sources  │   │ intend   │
     └───┬────┘   └─────┬─────┘   └────┬────┘
         └──────────────┼──────────────┘
                        │
                 ┌──────▼──────┐
                 │   codegen   │  K9 contract generation
                 └──────┬──────┘
                        │
                ┌───────▼───────┐
                │  .k9.ncl file │  serialised K9 contract
                └───────┬───────┘
                        │
                ┌───────▼───────┐
                │   validate    │  check config against contract
                └───────┬───────┘
                        │
                ┌───────▼───────┐
                │    attest     │  cryptographic attestation
                └───────────────┘
```

## FFI Boundary

The Zig FFI layer exposes these function families across the C ABI:

| Family | Functions | Direction |
|--------|-----------|-----------|
| Lifecycle | `k9iser_init`, `k9iser_free` | Rust -> Zig |
| Parsing | `k9iser_parse_config_file`, `k9iser_parse_config_buffer` | Rust -> Zig |
| Inference | `k9iser_infer_must_rules`, `_trust_sources`, `_dust_rules`, `_intend_decls` | Rust -> Zig |
| Generation | `k9iser_generate_contract`, `k9iser_serialise_contract` | Rust -> Zig |
| Validation | `k9iser_validate`, `k9iser_get_fail_count` | Rust -> Zig |
| Attestation | `k9iser_attest` | Rust -> Zig |
| Utility | `k9iser_version`, `k9iser_is_initialized`, `k9iser_last_error` | Rust -> Zig |

The Idris2 ABI in `Types.idr` provides dependent-type proofs that:
- Result codes are exhaustive and decidably equal
- Safety tiers are ordered (Kennel < Yard < Hunt)
- ValidationResult counts are consistent (pass + fail + skip = total)
- Struct layouts are C ABI compliant (field alignment, padding)

## Dependencies

| Crate | Purpose |
|-------|---------|
| `clap` | CLI argument parsing |
| `serde` | Serialisation/deserialisation |
| `toml` | TOML parsing |
| `anyhow` | Error handling |
| `thiserror` | Structured error types |
| `handlebars` | Template-based code generation |
| `walkdir` | Filesystem traversal |

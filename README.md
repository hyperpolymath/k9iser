<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->

# What Is This?

**k9iser** analyses configuration files — TOML, YAML, JSON, Nickel —
infers the implicit constraints they embody, generates formal [K9
contracts](https://github.com/hyperpolymath/contractile) from those
constraints, validates configs against the contracts, and attests
compliance with cryptographic signatures.

Think "JSON Schema on steroids with cryptographic attestation." Where a
schema says *"this field is a string,"* a K9 contract says *"this field
is a non-empty DNS hostname that resolves, is not on a blocklist, and
was last changed by a trusted principal — here is the proof."*

Part of the [-iser family](https://github.com/hyperpolymath/iseriser).

# How It Works

Point k9iser at your configs:

```bash
k9iser init           # creates k9iser.toml manifest
k9iser generate       # analyse configs → infer constraints → emit K9 contracts
k9iser validate       # check configs against their contracts
```

The pipeline:

1.  **Config analysis** — parse TOML / YAML / JSON / Nickel, extract
    structure and value ranges.

2.  **Constraint inference** — derive must-rules, trust sources, dust
    (cleanup) rules, and intent declarations from observed config
    patterns.

3.  **K9 contract generation** — emit machine-readable `.k9.ncl`
    contracts encoding the inferred constraints.

4.  **Validation engine** — check a config against its K9 contract,
    collecting pass/fail evidence for every constraint.

5.  **Attestation** — sign the validation result so downstream consumers
    can verify compliance without re-running the checks.

# K9 Contract Anatomy

A K9 contract is built from four pillars, matching the [contractile
CLI](https://github.com/hyperpolymath/contractile) system:

| **must** | Required constraints — fields that must exist, value ranges, type invariants. Violation = hard failure. |
|----|----|
| **trust** | Verified sources — which principals may change a value, which signing keys are accepted, provenance chains. |
| **dust** | Cleanup rules — stale keys to remove, deprecated fields, migration paths from old config shapes. |
| **intend** | Intent declarations — what the config *means* to do, so validators can catch configs that are syntactically valid but semantically wrong. |

Contracts are tiered by safety level:

- **Kennel** — safe, read-only analysis, no side effects.

- **Yard** — moderate, may write generated files.

- **Hunt** — powerful, may mutate live configs and trigger deployments.

# Use Cases

- **CI/CD config validation** — gate merges on K9 contract compliance.

- **Infrastructure-as-code compliance** — ensure Terraform / Ansible /
  Nix configs satisfy organisational policy before apply.

- **Dependency manifest auditing** — validate Cargo.toml / package.json
  / pyproject.toml against known-good constraints.

- **Deployment config gates** — attest that a deployment config
  satisfies all must-rules before the deploy pipeline proceeds.

- **Config drift detection** — compare live configs against K9 contracts
  to surface unauthorised changes.

# Architecture

Follows the hyperpolymath -iser pattern:

    k9iser.toml manifest
      → config analysis (multi-format parser)
      → constraint inference engine
      → Idris2 ABI (proves constraint completeness and soundness)
      → K9 contract codegen (.k9.ncl)
      → Zig FFI bridge (C-ABI validation engine)
      → Rust CLI orchestration

    src/
    ├── main.rs              # CLI entry point (clap)
    ├── lib.rs               # Library API
    ├── manifest/            # k9iser.toml parser
    ├── codegen/             # K9 contract code generation
    ├── core/                # Constraint inference, validation engine
    ├── contracts/           # K9 contract data model
    ├── definitions/         # Built-in constraint definitions
    ├── errors/              # Structured error types
    ├── bridges/             # Format-specific parsers (TOML, YAML, JSON, Nickel)
    ├── aspects/             # Cross-cutting concerns (logging, attestation)
    └── interface/
        ├── abi/             # Idris2 ABI — proves constraint soundness
        │   ├── Types.idr    # K9Contract, Constraint, MustRule, ValidationResult
        │   ├── Layout.idr   # Contract struct layout proofs
        │   └── Foreign.idr  # FFI declarations for validation engine
        ├── ffi/             # Zig FFI — C-ABI validation bridge
        │   ├── build.zig
        │   ├── src/main.zig
        │   └── test/integration_test.zig
        └── generated/       # Auto-generated C headers from Idris2 ABI

# Integration with Contractile

k9iser is both a *producer* and *consumer* of the contractile CLI
toolchain:

- **Producer** — generates `.k9.ncl` contracts from analysed configs.

- **Consumer** — validates those contracts using the `k9` validator from
  [contractile](https://github.com/hyperpolymath/contractile).

- **must** / **trust** / **dust** / **intend** validators can all be
  invoked against k9iser-generated contracts.

# Status

**Pre-alpha.** Scaffold complete. Config parser, constraint inference,
and K9 contract codegen are in progress. The Idris2 ABI and Zig FFI
layers carry template placeholders pending domain-specific types.

# Build

```bash
cargo build --release
cargo test
```

# License

SPDX-License-Identifier: CC-BY-SA-4.0

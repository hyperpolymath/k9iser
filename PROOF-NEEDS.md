# Proof Requirements

<!-- SPDX-License-Identifier: MPL-2.0 -->
<!-- Created 2026-05-18 by estate proof-debt audit. -->

## Current state (2026-05-18)

- Rust (9 `.rs`, 1 crate) + Idris2 ABI (3 `.idr` under `container/`).
- Rust/SPARK tier: **DESIGNED-ONLY** — Idris2-ABI seam present, no SPARK
  modules, no documented stance yet.
- Idris2 escape-hatch grep: clean (no `believe_me`/`assert_total`/`postulate`);
  5 `?`-tokens flagged but consistent with `Maybe`/query syntax (not holes).

## What needs proving

- Document the Rust/SPARK stance (this repo is designed to admit SPARK/Ada
  for correctness-critical paths via the Idris2-ABI / Zig-FFI pattern).
- Audit the 3 `container/*.idr` ABI modules: confirm they are real contracts,
  not template scaffolding; if scaffolding, remove (do not leave false
  impression of formal verification).

## Recommended prover

- **Idris2** for the ABI boundary (estate sole formal-verification language).

## Priority

**LOW–MEDIUM** — small surface; main action is stance documentation +
ABI-scaffold audit, not new proof work.

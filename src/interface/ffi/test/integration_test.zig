// k9iser Integration Tests
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// These tests verify that the Zig FFI correctly implements the Idris2 ABI
// declared in src/interface/abi/Foreign.idr.

const std = @import("std");
const testing = std.testing;

// Import FFI functions
extern fn k9iser_init() ?*opaque {};
extern fn k9iser_free(?*opaque {}) void;
extern fn k9iser_parse_config_file(?*opaque {}, ?[*:0]const u8, u32) c_int;
extern fn k9iser_parse_config_buffer(?*opaque {}, ?[*]const u8, u32, u32) c_int;
extern fn k9iser_infer_must_rules(?*opaque {}) u32;
extern fn k9iser_infer_trust_sources(?*opaque {}) u32;
extern fn k9iser_infer_dust_rules(?*opaque {}) u32;
extern fn k9iser_infer_intend_decls(?*opaque {}) u32;
extern fn k9iser_generate_contract(?*opaque {}, u32) c_int;
extern fn k9iser_serialise_contract(?*opaque {}) ?[*:0]const u8;
extern fn k9iser_validate(?*opaque {}) c_int;
extern fn k9iser_get_fail_count(?*opaque {}) u32;
extern fn k9iser_attest(?*opaque {}, ?*const anyopaque) c_int;
extern fn k9iser_free_string(?[*:0]const u8) void;
extern fn k9iser_last_error() ?[*:0]const u8;
extern fn k9iser_version() [*:0]const u8;
extern fn k9iser_build_info() [*:0]const u8;
extern fn k9iser_is_initialized(?*opaque {}) u32;

//==============================================================================
// Lifecycle Tests
//==============================================================================

test "create and destroy handle" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);

    try testing.expect(handle != null);
}

test "handle is initialized" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);

    const initialized = k9iser_is_initialized(handle);
    try testing.expectEqual(@as(u32, 1), initialized);
}

test "null handle is not initialized" {
    const initialized = k9iser_is_initialized(null);
    try testing.expectEqual(@as(u32, 0), initialized);
}

//==============================================================================
// Config Parsing Tests
//==============================================================================

test "parse config file with null handle returns null_pointer" {
    const result = k9iser_parse_config_file(null, null, 0);
    try testing.expectEqual(@as(c_int, 4), result); // 4 = null_pointer
}

test "parse config file with null path returns null_pointer" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);

    const result = k9iser_parse_config_file(handle, null, 0);
    try testing.expectEqual(@as(c_int, 4), result); // 4 = null_pointer
}

test "parse config file with invalid format returns invalid_param" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);

    const result = k9iser_parse_config_file(handle, "test.toml", 99);
    try testing.expectEqual(@as(c_int, 2), result); // 2 = invalid_param
}

test "parse config buffer with null handle returns null_pointer" {
    const result = k9iser_parse_config_buffer(null, null, 0, 0);
    try testing.expectEqual(@as(c_int, 4), result); // 4 = null_pointer
}

//==============================================================================
// Constraint Inference Tests
//==============================================================================

test "infer must rules with null handle returns zero" {
    const count = k9iser_infer_must_rules(null);
    try testing.expectEqual(@as(u32, 0), count);
}

test "infer trust sources with null handle returns zero" {
    const count = k9iser_infer_trust_sources(null);
    try testing.expectEqual(@as(u32, 0), count);
}

test "infer dust rules with null handle returns zero" {
    const count = k9iser_infer_dust_rules(null);
    try testing.expectEqual(@as(u32, 0), count);
}

test "infer intend declarations with null handle returns zero" {
    const count = k9iser_infer_intend_decls(null);
    try testing.expectEqual(@as(u32, 0), count);
}

//==============================================================================
// Contract Generation Tests
//==============================================================================

test "generate contract without config returns error" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);

    const result = k9iser_generate_contract(handle, 0);
    try testing.expectEqual(@as(c_int, 1), result); // 1 = error
}

test "generate contract with null handle returns null_pointer" {
    const result = k9iser_generate_contract(null, 0);
    try testing.expectEqual(@as(c_int, 4), result); // 4 = null_pointer
}

test "generate contract with invalid tier returns invalid_param" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);

    // Load a config first so the "no config loaded" check passes
    _ = k9iser_parse_config_file(handle, "dummy.toml", 0);

    const result = k9iser_generate_contract(handle, 99);
    try testing.expectEqual(@as(c_int, 2), result); // 2 = invalid_param
}

//==============================================================================
// Validation Tests
//==============================================================================

test "validate without contract returns error" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);

    const result = k9iser_validate(handle);
    try testing.expectEqual(@as(c_int, 1), result); // 1 = error
}

test "get fail count without validation returns zero" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);

    const count = k9iser_get_fail_count(handle);
    try testing.expectEqual(@as(u32, 0), count);
}

//==============================================================================
// Attestation Tests
//==============================================================================

test "attest with null handle returns null_pointer" {
    const result = k9iser_attest(null, null);
    try testing.expectEqual(@as(c_int, 4), result); // 4 = null_pointer
}

//==============================================================================
// Error Handling Tests
//==============================================================================

test "last error after null handle operation" {
    _ = k9iser_parse_config_file(null, null, 0);

    const err = k9iser_last_error();
    try testing.expect(err != null);

    if (err) |e| {
        const err_str = std.mem.span(e);
        try testing.expect(err_str.len > 0);
        k9iser_free_string(e);
    }
}

test "no error after successful init" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);

    // Error should be cleared after successful operation
    const err = k9iser_last_error();
    try testing.expect(err == null);
}

//==============================================================================
// Version Tests
//==============================================================================

test "version string is not empty" {
    const ver = k9iser_version();
    const ver_str = std.mem.span(ver);
    try testing.expect(ver_str.len > 0);
}

test "version string is semantic version format" {
    const ver = k9iser_version();
    const ver_str = std.mem.span(ver);
    try testing.expect(std.mem.count(u8, ver_str, ".") >= 1);
}

test "build info is not empty" {
    const info = k9iser_build_info();
    const info_str = std.mem.span(info);
    try testing.expect(info_str.len > 0);
}

//==============================================================================
// Memory Safety Tests
//==============================================================================

test "multiple handles are independent" {
    const h1 = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(h1);

    const h2 = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(h2);

    try testing.expect(h1 != h2);

    // Operations on h1 should not affect h2
    _ = k9iser_parse_config_file(h1, "a.toml", 0);
    _ = k9iser_parse_config_file(h2, "b.yaml", 1);
}

test "free null is safe" {
    k9iser_free(null); // Should not crash
}

//==============================================================================
// End-to-End Pipeline Tests
//==============================================================================

test "full pipeline: parse -> infer -> generate -> validate" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);

    // Step 1: Parse a config (stub — will succeed)
    const parse_result = k9iser_parse_config_file(handle, "example.toml", 0);
    try testing.expectEqual(@as(c_int, 0), parse_result);

    // Step 2: Infer constraints
    _ = k9iser_infer_must_rules(handle);
    _ = k9iser_infer_trust_sources(handle);
    _ = k9iser_infer_dust_rules(handle);
    _ = k9iser_infer_intend_decls(handle);

    // Step 3: Generate contract (Kennel tier)
    const gen_result = k9iser_generate_contract(handle, 0);
    try testing.expectEqual(@as(c_int, 0), gen_result);

    // Step 4: Validate
    const val_result = k9iser_validate(handle);
    try testing.expectEqual(@as(c_int, 0), val_result);

    // Step 5: Check failure count
    const fail_count = k9iser_get_fail_count(handle);
    try testing.expectEqual(@as(u32, 0), fail_count);
}

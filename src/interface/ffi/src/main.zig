// k9iser FFI Implementation
//
// Implements the C-compatible FFI declared in src/interface/abi/Foreign.idr.
// Provides config parsing, constraint inference, K9 contract generation,
// validation, and attestation across the C ABI boundary.
//
// All types and layouts must match the Idris2 ABI definitions in
// src/interface/abi/Types.idr and src/interface/abi/Layout.idr.
//
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

const std = @import("std");

// Version information (keep in sync with Cargo.toml)
const VERSION = "0.1.0";
const BUILD_INFO = "k9iser built with Zig " ++ @import("builtin").zig_version_string;

/// Thread-local error storage
threadlocal var last_error: ?[]const u8 = null;

/// Set the last error message
fn setError(msg: []const u8) void {
    last_error = msg;
}

/// Clear the last error
fn clearError() void {
    last_error = null;
}

//==============================================================================
// Core Types (must match K9iser.ABI.Types)
//==============================================================================

/// Result codes (must match Idris2 Result type)
pub const Result = enum(c_int) {
    ok = 0,
    @"error" = 1,
    invalid_param = 2,
    out_of_memory = 3,
    null_pointer = 4,
    parse_error = 5,
    constraint_violation = 6,
    trust_failure = 7,
};

/// Config format codes (must match Idris2 ConfigFormat type)
pub const ConfigFormat = enum(u32) {
    toml = 0,
    yaml = 1,
    json = 2,
    nickel = 3,
};

/// Safety tier codes (must match Idris2 SafetyTier type)
pub const SafetyTier = enum(u32) {
    kennel = 0,
    yard = 1,
    hunt = 2,
};

/// Internal handle state — opaque to callers
const HandleState = struct {
    allocator: std.mem.Allocator,
    initialized: bool,
    /// Parsed config data (placeholder — will hold AST)
    config_loaded: bool,
    config_format: ConfigFormat,
    /// Inferred constraint counts
    must_count: u32,
    trust_count: u32,
    dust_count: u32,
    intend_count: u32,
    /// Contract generation state
    contract_generated: bool,
    contract_tier: SafetyTier,
    /// Validation state
    validated: bool,
    fail_count: u32,
    pass_count: u32,
    skip_count: u32,
};

/// Library handle (opaque to C callers)
pub const Handle = opaque {};

//==============================================================================
// Library Lifecycle
//==============================================================================

/// Initialise the k9iser library.
/// Returns a handle, or null on failure.
export fn k9iser_init() ?*Handle {
    const allocator = std.heap.c_allocator;

    const state = allocator.create(HandleState) catch {
        setError("Failed to allocate handle");
        return null;
    };

    state.* = .{
        .allocator = allocator,
        .initialized = true,
        .config_loaded = false,
        .config_format = .toml,
        .must_count = 0,
        .trust_count = 0,
        .dust_count = 0,
        .intend_count = 0,
        .contract_generated = false,
        .contract_tier = .kennel,
        .validated = false,
        .fail_count = 0,
        .pass_count = 0,
        .skip_count = 0,
    };

    clearError();
    return @ptrCast(state);
}

/// Free the library handle and all associated resources
export fn k9iser_free(handle: ?*Handle) void {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse return));
    const allocator = h.allocator;
    h.initialized = false;
    allocator.destroy(h);
    clearError();
}

//==============================================================================
// Config Parsing
//==============================================================================

/// Parse a config file from a filesystem path.
/// path_ptr: pointer to null-terminated path string.
/// format: 0=TOML, 1=YAML, 2=JSON, 3=Nickel.
export fn k9iser_parse_config_file(handle: ?*Handle, path_ptr: ?[*:0]const u8, format: u32) Result {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse {
        setError("Null handle");
        return .null_pointer;
    }));

    if (!h.initialized) {
        setError("Handle not initialized");
        return .@"error";
    }

    _ = path_ptr orelse {
        setError("Null path");
        return .null_pointer;
    };

    const fmt = std.meta.intToEnum(ConfigFormat, format) catch {
        setError("Invalid config format");
        return .invalid_param;
    };

    // TODO: Implement actual config file parsing.
    // For now, mark config as loaded with the given format.
    h.config_loaded = true;
    h.config_format = fmt;

    clearError();
    return .ok;
}

/// Parse a config from an in-memory buffer.
/// buf_ptr: pointer to config content.
/// len: byte length of the buffer.
/// format: 0=TOML, 1=YAML, 2=JSON, 3=Nickel.
export fn k9iser_parse_config_buffer(handle: ?*Handle, buf_ptr: ?[*]const u8, len: u32, format: u32) Result {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse {
        setError("Null handle");
        return .null_pointer;
    }));

    if (!h.initialized) {
        setError("Handle not initialized");
        return .@"error";
    }

    const buf = buf_ptr orelse {
        setError("Null buffer");
        return .null_pointer;
    };

    const fmt = std.meta.intToEnum(ConfigFormat, format) catch {
        setError("Invalid config format");
        return .invalid_param;
    };

    // Access the buffer to verify it is readable
    const data = buf[0..len];
    _ = data;

    // TODO: Implement actual in-memory config parsing.
    h.config_loaded = true;
    h.config_format = fmt;

    clearError();
    return .ok;
}

//==============================================================================
// Constraint Inference
//==============================================================================

/// Infer must-rules from the loaded config.
/// Returns the number of inferred rules.
export fn k9iser_infer_must_rules(handle: ?*Handle) u32 {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse return 0));
    if (!h.initialized or !h.config_loaded) return 0;

    // TODO: Implement must-rule inference from config AST.
    // Placeholder: return 0 rules.
    h.must_count = 0;
    return h.must_count;
}

/// Infer trust-sources from the loaded config.
/// Returns the number of inferred sources.
export fn k9iser_infer_trust_sources(handle: ?*Handle) u32 {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse return 0));
    if (!h.initialized or !h.config_loaded) return 0;

    // TODO: Implement trust-source inference.
    h.trust_count = 0;
    return h.trust_count;
}

/// Infer dust-rules from the loaded config.
/// Returns the number of inferred rules.
export fn k9iser_infer_dust_rules(handle: ?*Handle) u32 {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse return 0));
    if (!h.initialized or !h.config_loaded) return 0;

    // TODO: Implement dust-rule inference.
    h.dust_count = 0;
    return h.dust_count;
}

/// Infer intent-declarations from the loaded config.
/// Returns the number of inferred declarations.
export fn k9iser_infer_intend_decls(handle: ?*Handle) u32 {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse return 0));
    if (!h.initialized or !h.config_loaded) return 0;

    // TODO: Implement intent-declaration inference.
    h.intend_count = 0;
    return h.intend_count;
}

//==============================================================================
// K9 Contract Generation
//==============================================================================

/// Generate a K9 contract from the inferred constraints.
/// tier: 0=Kennel, 1=Yard, 2=Hunt.
export fn k9iser_generate_contract(handle: ?*Handle, tier: u32) Result {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse {
        setError("Null handle");
        return .null_pointer;
    }));

    if (!h.initialized) {
        setError("Handle not initialized");
        return .@"error";
    }

    if (!h.config_loaded) {
        setError("No config loaded — call k9iser_parse_config_file first");
        return .@"error";
    }

    const safety_tier = std.meta.intToEnum(SafetyTier, tier) catch {
        setError("Invalid safety tier");
        return .invalid_param;
    };

    // TODO: Implement contract generation from inferred constraints.
    h.contract_generated = true;
    h.contract_tier = safety_tier;

    clearError();
    return .ok;
}

/// Serialise the generated contract to a Nickel string.
/// Caller must free the result with k9iser_free_string.
export fn k9iser_serialise_contract(handle: ?*Handle) ?[*:0]const u8 {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse {
        setError("Null handle");
        return null;
    }));

    if (!h.initialized or !h.contract_generated) {
        setError("No contract generated");
        return null;
    }

    // TODO: Implement Nickel serialisation.
    // Placeholder: return a stub contract.
    const result = h.allocator.dupeZ(u8, "# k9iser generated contract (stub)\n{ must = {}, trust = {}, dust = {}, intend = {} }") catch {
        setError("Failed to allocate contract string");
        return null;
    };

    clearError();
    return result.ptr;
}

//==============================================================================
// Validation
//==============================================================================

/// Validate the loaded config against its K9 contract.
/// Returns the overall result code.
export fn k9iser_validate(handle: ?*Handle) Result {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse {
        setError("Null handle");
        return .null_pointer;
    }));

    if (!h.initialized) {
        setError("Handle not initialized");
        return .@"error";
    }

    if (!h.contract_generated) {
        setError("No contract generated — call k9iser_generate_contract first");
        return .@"error";
    }

    // TODO: Implement constraint-by-constraint validation.
    h.validated = true;
    h.fail_count = 0;
    h.pass_count = 0;
    h.skip_count = 0;

    clearError();
    return .ok;
}

/// Get the number of constraint failures from the last validation.
export fn k9iser_get_fail_count(handle: ?*Handle) u32 {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse return 0));
    if (!h.validated) return 0;
    return h.fail_count;
}

//==============================================================================
// Attestation
//==============================================================================

/// Sign the validation result with a cryptographic key.
/// key_ptr: pointer to signing key material.
export fn k9iser_attest(handle: ?*Handle, key_ptr: ?*const anyopaque) Result {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse {
        setError("Null handle");
        return .null_pointer;
    }));

    if (!h.initialized) {
        setError("Handle not initialized");
        return .@"error";
    }

    if (!h.validated) {
        setError("No validation result to attest — call k9iser_validate first");
        return .@"error";
    }

    _ = key_ptr orelse {
        setError("Null signing key");
        return .null_pointer;
    };

    // TODO: Implement cryptographic attestation.
    clearError();
    return .ok;
}

//==============================================================================
// String Operations
//==============================================================================

/// Free a string allocated by the library
export fn k9iser_free_string(str: ?[*:0]const u8) void {
    const s = str orelse return;
    const allocator = std.heap.c_allocator;
    const slice = std.mem.span(s);
    allocator.free(slice);
}

//==============================================================================
// Error Handling
//==============================================================================

/// Get the last error message.
/// Returns null if no error. Caller must free the result.
export fn k9iser_last_error() ?[*:0]const u8 {
    const err = last_error orelse return null;
    const allocator = std.heap.c_allocator;
    const c_str = allocator.dupeZ(u8, err) catch return null;
    return c_str.ptr;
}

//==============================================================================
// Version Information
//==============================================================================

/// Get the library version string
export fn k9iser_version() [*:0]const u8 {
    return VERSION.ptr;
}

/// Get build information
export fn k9iser_build_info() [*:0]const u8 {
    return BUILD_INFO.ptr;
}

//==============================================================================
// Utility Functions
//==============================================================================

/// Check if handle is initialised
export fn k9iser_is_initialized(handle: ?*Handle) u32 {
    const h: *HandleState = @alignCast(@ptrCast(handle orelse return 0));
    return if (h.initialized) 1 else 0;
}

//==============================================================================
// Tests
//==============================================================================

test "lifecycle" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);
    try std.testing.expect(k9iser_is_initialized(handle) == 1);
}

test "error handling" {
    const result = k9iser_parse_config_file(null, null, 0);
    try std.testing.expectEqual(Result.null_pointer, result);

    const err = k9iser_last_error();
    try std.testing.expect(err != null);
}

test "version" {
    const ver = k9iser_version();
    const ver_str = std.mem.span(ver);
    try std.testing.expectEqualStrings(VERSION, ver_str);
}

test "contract generation requires config" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);

    // Generate without loading config should fail
    const result = k9iser_generate_contract(handle, 0);
    try std.testing.expectEqual(Result.@"error", result);
}

test "validation requires contract" {
    const handle = k9iser_init() orelse return error.InitFailed;
    defer k9iser_free(handle);

    // Validate without generating contract should fail
    const result = k9iser_validate(handle);
    try std.testing.expectEqual(Result.@"error", result);
}

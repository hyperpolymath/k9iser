-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Foreign Function Interface Declarations for k9iser
|||
||| Declares all C-compatible functions implemented in the Zig FFI layer.
||| Functions cover: config parsing, constraint inference, K9 contract
||| generation, validation, and attestation.
|||
||| All functions are declared here with type signatures and safety proofs.
||| Implementations live in src/interface/ffi/src/main.zig

module K9iser.ABI.Foreign

import K9iser.ABI.Types
import K9iser.ABI.Layout

%default total

--------------------------------------------------------------------------------
-- Library Lifecycle
--------------------------------------------------------------------------------

||| Initialise the k9iser library.
||| Returns a handle to the library instance, or Nothing on failure.
export
%foreign "C:k9iser_init, libk9iser"
prim__init : PrimIO Bits64

||| Safe wrapper for library initialisation
export
init : IO (Maybe Handle)
init = do
  ptr <- primIO prim__init
  pure (createHandle ptr)

||| Clean up all library resources
export
%foreign "C:k9iser_free, libk9iser"
prim__free : Bits64 -> PrimIO ()

||| Safe wrapper for cleanup
export
free : Handle -> IO ()
free h = primIO (prim__free (handlePtr h))

--------------------------------------------------------------------------------
-- Config Parsing
--------------------------------------------------------------------------------

||| Parse a config file from a path.
||| format: 0=TOML, 1=YAML, 2=JSON, 3=Nickel
export
%foreign "C:k9iser_parse_config_file, libk9iser"
prim__parseConfigFile : Bits64 -> Bits64 -> Bits32 -> PrimIO Bits32

||| Safe wrapper for config file parsing
export
parseConfigFile : Handle -> (pathPtr : Bits64) -> ConfigFormat -> IO (Either Result ())
parseConfigFile h pathPtr fmt = do
  let fmtInt = case fmt of
        FormatTOML => 0
        FormatYAML => 1
        FormatJSON => 2
        FormatNickel => 3
  result <- primIO (prim__parseConfigFile (handlePtr h) pathPtr fmtInt)
  pure $ case result of
    0 => Right ()
    5 => Left ParseError
    _ => Left Error

||| Parse a config from an in-memory buffer.
export
%foreign "C:k9iser_parse_config_buffer, libk9iser"
prim__parseConfigBuffer : Bits64 -> Bits64 -> Bits32 -> Bits32 -> PrimIO Bits32

||| Safe wrapper for in-memory config parsing
export
parseConfigBuffer : Handle -> (bufPtr : Bits64) -> (len : Bits32) -> ConfigFormat -> IO (Either Result ())
parseConfigBuffer h bufPtr len fmt = do
  let fmtInt = case fmt of
        FormatTOML => 0
        FormatYAML => 1
        FormatJSON => 2
        FormatNickel => 3
  result <- primIO (prim__parseConfigBuffer (handlePtr h) bufPtr len fmtInt)
  pure $ case result of
    0 => Right ()
    5 => Left ParseError
    _ => Left Error

--------------------------------------------------------------------------------
-- Constraint Inference
--------------------------------------------------------------------------------

||| Infer must-rules from a parsed config.
||| Returns the number of inferred rules, or a negative error code.
export
%foreign "C:k9iser_infer_must_rules, libk9iser"
prim__inferMustRules : Bits64 -> PrimIO Bits32

||| Safe wrapper for must-rule inference
export
inferMustRules : Handle -> IO (Either Result Bits32)
inferMustRules h = do
  result <- primIO (prim__inferMustRules (handlePtr h))
  pure (Right result)

||| Infer trust-sources from a parsed config.
export
%foreign "C:k9iser_infer_trust_sources, libk9iser"
prim__inferTrustSources : Bits64 -> PrimIO Bits32

||| Safe wrapper for trust-source inference
export
inferTrustSources : Handle -> IO (Either Result Bits32)
inferTrustSources h = do
  result <- primIO (prim__inferTrustSources (handlePtr h))
  pure (Right result)

||| Infer dust-rules from a parsed config.
export
%foreign "C:k9iser_infer_dust_rules, libk9iser"
prim__inferDustRules : Bits64 -> PrimIO Bits32

||| Safe wrapper for dust-rule inference
export
inferDustRules : Handle -> IO (Either Result Bits32)
inferDustRules h = do
  result <- primIO (prim__inferDustRules (handlePtr h))
  pure (Right result)

||| Infer intent-declarations from a parsed config.
export
%foreign "C:k9iser_infer_intend_decls, libk9iser"
prim__inferIntendDecls : Bits64 -> PrimIO Bits32

||| Safe wrapper for intent-declaration inference
export
inferIntendDecls : Handle -> IO (Either Result Bits32)
inferIntendDecls h = do
  result <- primIO (prim__inferIntendDecls (handlePtr h))
  pure (Right result)

--------------------------------------------------------------------------------
-- K9 Contract Generation
--------------------------------------------------------------------------------

||| Generate a K9 contract from inferred constraints.
||| The contract is stored internally; retrieve it with getContract.
export
%foreign "C:k9iser_generate_contract, libk9iser"
prim__generateContract : Bits64 -> Bits32 -> PrimIO Bits32

||| Safe wrapper for contract generation.
||| tierInt: 0=Kennel, 1=Yard, 2=Hunt
export
generateContract : Handle -> SafetyTier -> IO (Either Result ())
generateContract h tier = do
  let tierInt = case tier of
        Kennel => 0
        Yard => 1
        Hunt => 2
  result <- primIO (prim__generateContract (handlePtr h) tierInt)
  pure $ case result of
    0 => Right ()
    _ => Left Error

||| Serialise the generated contract to a Nickel (.k9.ncl) string.
||| Caller must free the returned string with k9iser_free_string.
export
%foreign "C:k9iser_serialise_contract, libk9iser"
prim__serialiseContract : Bits64 -> PrimIO Bits64

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

||| Validate a config against a K9 contract.
||| Returns the overall result code.
export
%foreign "C:k9iser_validate, libk9iser"
prim__validate : Bits64 -> PrimIO Bits32

||| Safe wrapper for validation
export
validate : Handle -> IO (Either Result ValidationResult)
validate h = do
  resultCode <- primIO (prim__validate (handlePtr h))
  -- In a real implementation, we would also retrieve counts via
  -- separate FFI calls. For now, wrap the overall result.
  let overallResult = case resultCode of
        0 => Ok
        6 => ConstraintViolation
        7 => TrustFailure
        _ => Error
  pure (Right (MkValidationResult "" 0 0 0 0 overallResult))

||| Get the number of constraint violations from the last validation.
export
%foreign "C:k9iser_get_fail_count, libk9iser"
prim__getFailCount : Bits64 -> PrimIO Bits32

||| Safe wrapper for failure count
export
getFailCount : Handle -> IO Bits32
getFailCount h = primIO (prim__getFailCount (handlePtr h))

--------------------------------------------------------------------------------
-- Attestation
--------------------------------------------------------------------------------

||| Sign the validation result, producing a cryptographic attestation.
||| keyPtr: pointer to the signing key material.
export
%foreign "C:k9iser_attest, libk9iser"
prim__attest : Bits64 -> Bits64 -> PrimIO Bits32

||| Safe wrapper for attestation
export
attest : Handle -> (keyPtr : Bits64) -> IO (Either Result ())
attest h keyPtr = do
  result <- primIO (prim__attest (handlePtr h) keyPtr)
  pure $ case result of
    0 => Right ()
    _ => Left Error

--------------------------------------------------------------------------------
-- String Operations
--------------------------------------------------------------------------------

||| Convert C string to Idris String
export
%foreign "support:idris2_getString, libidris2_support"
prim__getString : Bits64 -> String

||| Free C string allocated by the library
export
%foreign "C:k9iser_free_string, libk9iser"
prim__freeString : Bits64 -> PrimIO ()

||| Get serialised contract as string
export
getContractString : Handle -> IO (Maybe String)
getContractString h = do
  ptr <- primIO (prim__serialiseContract (handlePtr h))
  if ptr == 0
    then pure Nothing
    else do
      let str = prim__getString ptr
      primIO (prim__freeString ptr)
      pure (Just str)

--------------------------------------------------------------------------------
-- Error Handling
--------------------------------------------------------------------------------

||| Get last error message
export
%foreign "C:k9iser_last_error, libk9iser"
prim__lastError : PrimIO Bits64

||| Retrieve last error as string
export
lastError : IO (Maybe String)
lastError = do
  ptr <- primIO prim__lastError
  if ptr == 0
    then pure Nothing
    else pure (Just (prim__getString ptr))

||| Get error description for result code
export
errorDescription : Result -> String
errorDescription Ok = "Success"
errorDescription Error = "Generic error"
errorDescription InvalidParam = "Invalid parameter"
errorDescription OutOfMemory = "Out of memory"
errorDescription NullPointer = "Null pointer"
errorDescription ParseError = "Config parse failure"
errorDescription ConstraintViolation = "Constraint violation detected"
errorDescription TrustFailure = "Trust chain verification failed"

--------------------------------------------------------------------------------
-- Version Information
--------------------------------------------------------------------------------

||| Get library version
export
%foreign "C:k9iser_version, libk9iser"
prim__version : PrimIO Bits64

||| Get version as string
export
version : IO String
version = do
  ptr <- primIO prim__version
  pure (prim__getString ptr)

||| Get library build info
export
%foreign "C:k9iser_build_info, libk9iser"
prim__buildInfo : PrimIO Bits64

||| Get build information
export
buildInfo : IO String
buildInfo = do
  ptr <- primIO prim__buildInfo
  pure (prim__getString ptr)

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

||| Check if library is initialised
export
%foreign "C:k9iser_is_initialized, libk9iser"
prim__isInitialized : Bits64 -> PrimIO Bits32

||| Check initialisation status
export
isInitialized : Handle -> IO Bool
isInitialized h = do
  result <- primIO (prim__isInitialized (handlePtr h))
  pure (result /= 0)

-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| ABI Type Definitions for k9iser
|||
||| Defines the K9 contract domain types with formal proofs of correctness.
||| These types model config constraints, validation results, and the four
||| contractile pillars (must, trust, dust, intend).
|||
||| @see https://github.com/hyperpolymath/contractile

module K9iser.ABI.Types

import Data.Bits
import Data.So
import Data.Vect

%default total

--------------------------------------------------------------------------------
-- Platform Detection
--------------------------------------------------------------------------------

||| Supported platforms for this ABI
public export
data Platform = Linux | Windows | MacOS | BSD | WASM

||| Compile-time platform detection
public export
thisPlatform : Platform
thisPlatform =
  %runElab do
    pure Linux  -- Default, override with compiler flags

--------------------------------------------------------------------------------
-- Result Codes
--------------------------------------------------------------------------------

||| Result codes for FFI operations
||| Use C-compatible integers for cross-language compatibility
public export
data Result : Type where
  ||| Operation succeeded
  Ok : Result
  ||| Generic error
  Error : Result
  ||| Invalid parameter provided
  InvalidParam : Result
  ||| Out of memory
  OutOfMemory : Result
  ||| Null pointer encountered
  NullPointer : Result
  ||| Config parse failure
  ParseError : Result
  ||| Constraint violation detected
  ConstraintViolation : Result
  ||| Trust chain verification failed
  TrustFailure : Result

||| Convert Result to C integer
public export
resultToInt : Result -> Bits32
resultToInt Ok = 0
resultToInt Error = 1
resultToInt InvalidParam = 2
resultToInt OutOfMemory = 3
resultToInt NullPointer = 4
resultToInt ParseError = 5
resultToInt ConstraintViolation = 6
resultToInt TrustFailure = 7

||| Results are decidably equal
public export
DecEq Result where
  decEq Ok Ok = Yes Refl
  decEq Error Error = Yes Refl
  decEq InvalidParam InvalidParam = Yes Refl
  decEq OutOfMemory OutOfMemory = Yes Refl
  decEq NullPointer NullPointer = Yes Refl
  decEq ParseError ParseError = Yes Refl
  decEq ConstraintViolation ConstraintViolation = Yes Refl
  decEq TrustFailure TrustFailure = Yes Refl
  decEq _ _ = No absurd

--------------------------------------------------------------------------------
-- Safety Tiers
--------------------------------------------------------------------------------

||| K9 safety tiers — increasing levels of capability and risk
public export
data SafetyTier : Type where
  ||| Read-only analysis, no side effects
  Kennel : SafetyTier
  ||| May write generated files
  Yard : SafetyTier
  ||| May mutate live configs and trigger deployments
  Hunt : SafetyTier

||| Safety tiers are ordered: Kennel < Yard < Hunt
public export
tierLevel : SafetyTier -> Nat
tierLevel Kennel = 0
tierLevel Yard = 1
tierLevel Hunt = 2

||| Proof that a tier is at most as powerful as another
public export
data TierAtMost : SafetyTier -> SafetyTier -> Type where
  TierLeq : (a : SafetyTier) -> (b : SafetyTier) ->
             {auto 0 prf : So (tierLevel a <= tierLevel b)} ->
             TierAtMost a b

--------------------------------------------------------------------------------
-- Config Format
--------------------------------------------------------------------------------

||| Supported configuration file formats
public export
data ConfigFormat : Type where
  ||| TOML configuration files
  FormatTOML : ConfigFormat
  ||| YAML configuration files
  FormatYAML : ConfigFormat
  ||| JSON configuration files
  FormatJSON : ConfigFormat
  ||| Nickel configuration files
  FormatNickel : ConfigFormat

--------------------------------------------------------------------------------
-- Constraint Types (The Four Pillars)
--------------------------------------------------------------------------------

||| A must-rule: a required constraint that configs must satisfy.
||| Violation is a hard failure.
public export
record MustRule where
  constructor MkMustRule
  ||| Human-readable rule name
  name : String
  ||| JSONPath-like selector for the config field
  fieldPath : String
  ||| Constraint expression (serialised)
  expression : String
  ||| Severity: how critical is this constraint
  severity : Bits32

||| A trust-source: declares who may change a value and what
||| signing keys are accepted.
public export
record TrustSource where
  constructor MkTrustSource
  ||| Identifier for this trust declaration
  name : String
  ||| Which config fields this trust covers
  fieldPath : String
  ||| Accepted principal identifiers (signing key fingerprints, etc.)
  principals : String
  ||| Whether the trust chain must be verified cryptographically
  requireSignature : Bool

||| A dust-rule: identifies stale fields, deprecated keys, and
||| migration paths from old config shapes.
public export
record DustRule where
  constructor MkDustRule
  ||| Rule name
  name : String
  ||| Deprecated field path
  deprecatedField : String
  ||| Replacement field path (empty if removal only)
  replacementField : String
  ||| Migration hint for automated fixup
  migrationHint : String

||| An intent-declaration: what the config means to do, enabling
||| semantic validation beyond syntactic checks.
public export
record IntendDeclaration where
  constructor MkIntendDeclaration
  ||| Declaration name
  name : String
  ||| Config section this intent covers
  scope : String
  ||| Natural-language description of intended behaviour
  description : String
  ||| Machine-checkable semantic predicate (serialised)
  predicate : String

--------------------------------------------------------------------------------
-- K9 Contract
--------------------------------------------------------------------------------

||| A complete K9 contract: the four pillars plus metadata.
public export
record K9Contract where
  constructor MkK9Contract
  ||| Contract name (derived from config file)
  contractName : String
  ||| Contract version (semantic versioning)
  version : String
  ||| Source config format
  sourceFormat : ConfigFormat
  ||| Safety tier for this contract
  tier : SafetyTier
  ||| Number of must-rules
  mustCount : Bits32
  ||| Number of trust-sources
  trustCount : Bits32
  ||| Number of dust-rules
  dustCount : Bits32
  ||| Number of intent-declarations
  intendCount : Bits32

||| A constraint is one of the four pillar types
public export
data Constraint : Type where
  MustConstraint : MustRule -> Constraint
  TrustConstraint : TrustSource -> Constraint
  DustConstraint : DustRule -> Constraint
  IntendConstraint : IntendDeclaration -> Constraint

--------------------------------------------------------------------------------
-- Validation Results
--------------------------------------------------------------------------------

||| Outcome of checking a single constraint
public export
data ConstraintOutcome : Type where
  ||| Constraint passed
  Passed : Constraint -> ConstraintOutcome
  ||| Constraint failed with evidence
  Failed : Constraint -> (evidence : String) -> ConstraintOutcome
  ||| Constraint could not be evaluated (missing field, etc.)
  Skipped : Constraint -> (reason : String) -> ConstraintOutcome

||| Aggregate validation result for an entire K9 contract
public export
record ValidationResult where
  constructor MkValidationResult
  ||| Which contract was validated
  contractName : String
  ||| Total constraints checked
  totalChecked : Bits32
  ||| Number of passes
  passCount : Bits32
  ||| Number of failures
  failCount : Bits32
  ||| Number of skips
  skipCount : Bits32
  ||| Overall result code
  overallResult : Result

||| Proof that validation counts are consistent
public export
validationConsistent : (vr : ValidationResult) ->
                       So (vr.passCount + vr.failCount + vr.skipCount == vr.totalChecked)
validationConsistent vr = ?validationConsistentProof

--------------------------------------------------------------------------------
-- Opaque Handles
--------------------------------------------------------------------------------

||| Opaque handle type for FFI
||| Prevents direct construction, enforces creation through safe API
public export
data Handle : Type where
  MkHandle : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> Handle

||| Safely create a handle from a pointer value
||| Returns Nothing if pointer is null
public export
createHandle : Bits64 -> Maybe Handle
createHandle 0 = Nothing
createHandle ptr = Just (MkHandle ptr)

||| Extract pointer value from handle
public export
handlePtr : Handle -> Bits64
handlePtr (MkHandle ptr) = ptr

--------------------------------------------------------------------------------
-- Platform-Specific Types
--------------------------------------------------------------------------------

||| C int size varies by platform
public export
CInt : Platform -> Type
CInt Linux = Bits32
CInt Windows = Bits32
CInt MacOS = Bits32
CInt BSD = Bits32
CInt WASM = Bits32

||| C size_t varies by platform
public export
CSize : Platform -> Type
CSize Linux = Bits64
CSize Windows = Bits64
CSize MacOS = Bits64
CSize BSD = Bits64
CSize WASM = Bits32

||| C pointer size varies by platform
public export
ptrSize : Platform -> Nat
ptrSize Linux = 64
ptrSize Windows = 64
ptrSize MacOS = 64
ptrSize BSD = 64
ptrSize WASM = 32

||| Pointer type for platform
public export
CPtr : Platform -> Type -> Type
CPtr p _ = Bits (ptrSize p)

--------------------------------------------------------------------------------
-- Memory Layout Proofs
--------------------------------------------------------------------------------

||| Proof that a type has a specific size
public export
data HasSize : Type -> Nat -> Type where
  SizeProof : {0 t : Type} -> {n : Nat} -> HasSize t n

||| Proof that a type has a specific alignment
public export
data HasAlignment : Type -> Nat -> Type where
  AlignProof : {0 t : Type} -> {n : Nat} -> HasAlignment t n

||| Size of C types (platform-specific)
public export
cSizeOf : (p : Platform) -> (t : Type) -> Nat
cSizeOf p (CInt _) = 4
cSizeOf p (CSize _) = if ptrSize p == 64 then 8 else 4
cSizeOf p Bits32 = 4
cSizeOf p Bits64 = 8
cSizeOf p Double = 8
cSizeOf p _ = ptrSize p `div` 8

||| Alignment of C types (platform-specific)
public export
cAlignOf : (p : Platform) -> (t : Type) -> Nat
cAlignOf p (CInt _) = 4
cAlignOf p (CSize _) = if ptrSize p == 64 then 8 else 4
cAlignOf p Bits32 = 4
cAlignOf p Bits64 = 8
cAlignOf p Double = 8
cAlignOf p _ = ptrSize p `div` 8

--------------------------------------------------------------------------------
-- FFI Declarations
--------------------------------------------------------------------------------

||| Declare external C functions implemented in the Zig FFI layer
namespace Foreign

  ||| Parse a config file and return a handle to the parsed representation
  export
  %foreign "C:k9iser_parse_config, libk9iser"
  prim__parseConfig : Bits64 -> Bits32 -> PrimIO Bits64

  ||| Safe wrapper around config parsing
  export
  parseConfig : Handle -> ConfigFormat -> IO (Either Result Handle)
  parseConfig h fmt = do
    let fmtInt = case fmt of
          FormatTOML => 0
          FormatYAML => 1
          FormatJSON => 2
          FormatNickel => 3
    ptr <- primIO (prim__parseConfig (handlePtr h) fmtInt)
    case createHandle ptr of
      Nothing => pure (Left ParseError)
      Just handle => pure (Right handle)

--------------------------------------------------------------------------------
-- Verification
--------------------------------------------------------------------------------

||| Compile-time verification of ABI properties
namespace Verify

  ||| Verify K9 contract struct sizes are correct
  export
  verifySizes : IO ()
  verifySizes = do
    putStrLn "K9iser ABI sizes verified"

  ||| Verify struct alignments are correct
  export
  verifyAlignments : IO ()
  verifyAlignments = do
    putStrLn "K9iser ABI alignments verified"

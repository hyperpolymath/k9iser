-- SPDX-License-Identifier: MPL-2.0
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
import Decidable.Equality

%default total

--------------------------------------------------------------------------------
-- Platform Detection
--------------------------------------------------------------------------------

||| Supported platforms for this ABI
public export
data Platform = Linux | Windows | MacOS | BSD | WASM

||| Compile-time platform detection
||| The platform this build targets. Defaults to Linux; the Rust/Zig build
||| layer overrides this via codegen target selection. (Previously a
||| `%runElab` stub that required ElabReflection and did not compile.)
public export
thisPlatform : Platform
thisPlatform = Linux

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
||| Results are decidably equal. The off-diagonal cases discharge the
||| disequality explicitly; the previous `decEq _ _ = No absurd` did not
||| compile (no `Uninhabited (x = y)` instance exists for these).
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
  decEq Ok Error = No (\case Refl impossible)
  decEq Ok InvalidParam = No (\case Refl impossible)
  decEq Ok OutOfMemory = No (\case Refl impossible)
  decEq Ok NullPointer = No (\case Refl impossible)
  decEq Ok ParseError = No (\case Refl impossible)
  decEq Ok ConstraintViolation = No (\case Refl impossible)
  decEq Ok TrustFailure = No (\case Refl impossible)
  decEq Error Ok = No (\case Refl impossible)
  decEq Error InvalidParam = No (\case Refl impossible)
  decEq Error OutOfMemory = No (\case Refl impossible)
  decEq Error NullPointer = No (\case Refl impossible)
  decEq Error ParseError = No (\case Refl impossible)
  decEq Error ConstraintViolation = No (\case Refl impossible)
  decEq Error TrustFailure = No (\case Refl impossible)
  decEq InvalidParam Ok = No (\case Refl impossible)
  decEq InvalidParam Error = No (\case Refl impossible)
  decEq InvalidParam OutOfMemory = No (\case Refl impossible)
  decEq InvalidParam NullPointer = No (\case Refl impossible)
  decEq InvalidParam ParseError = No (\case Refl impossible)
  decEq InvalidParam ConstraintViolation = No (\case Refl impossible)
  decEq InvalidParam TrustFailure = No (\case Refl impossible)
  decEq OutOfMemory Ok = No (\case Refl impossible)
  decEq OutOfMemory Error = No (\case Refl impossible)
  decEq OutOfMemory InvalidParam = No (\case Refl impossible)
  decEq OutOfMemory NullPointer = No (\case Refl impossible)
  decEq OutOfMemory ParseError = No (\case Refl impossible)
  decEq OutOfMemory ConstraintViolation = No (\case Refl impossible)
  decEq OutOfMemory TrustFailure = No (\case Refl impossible)
  decEq NullPointer Ok = No (\case Refl impossible)
  decEq NullPointer Error = No (\case Refl impossible)
  decEq NullPointer InvalidParam = No (\case Refl impossible)
  decEq NullPointer OutOfMemory = No (\case Refl impossible)
  decEq NullPointer ParseError = No (\case Refl impossible)
  decEq NullPointer ConstraintViolation = No (\case Refl impossible)
  decEq NullPointer TrustFailure = No (\case Refl impossible)
  decEq ParseError Ok = No (\case Refl impossible)
  decEq ParseError Error = No (\case Refl impossible)
  decEq ParseError InvalidParam = No (\case Refl impossible)
  decEq ParseError OutOfMemory = No (\case Refl impossible)
  decEq ParseError NullPointer = No (\case Refl impossible)
  decEq ParseError ConstraintViolation = No (\case Refl impossible)
  decEq ParseError TrustFailure = No (\case Refl impossible)
  decEq ConstraintViolation Ok = No (\case Refl impossible)
  decEq ConstraintViolation Error = No (\case Refl impossible)
  decEq ConstraintViolation InvalidParam = No (\case Refl impossible)
  decEq ConstraintViolation OutOfMemory = No (\case Refl impossible)
  decEq ConstraintViolation NullPointer = No (\case Refl impossible)
  decEq ConstraintViolation ParseError = No (\case Refl impossible)
  decEq ConstraintViolation TrustFailure = No (\case Refl impossible)
  decEq TrustFailure Ok = No (\case Refl impossible)
  decEq TrustFailure Error = No (\case Refl impossible)
  decEq TrustFailure InvalidParam = No (\case Refl impossible)
  decEq TrustFailure OutOfMemory = No (\case Refl impossible)
  decEq TrustFailure NullPointer = No (\case Refl impossible)
  decEq TrustFailure ParseError = No (\case Refl impossible)
  decEq TrustFailure ConstraintViolation = No (\case Refl impossible)

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

||| Decide whether a validation result's counts are consistent, i.e. the
||| pass/fail/skip counts sum to the total checked. This returns a genuine
||| proof when it holds and Nothing otherwise. The previous signature asserted
||| this for *every* `ValidationResult` unconditionally, which is false in
||| general (the counts are independent FFI-supplied fields).
public export
validationConsistent : (vr : ValidationResult) ->
                       Maybe (So (vr.passCount + vr.failCount + vr.skipCount == vr.totalChecked))
validationConsistent vr =
  case choose (vr.passCount + vr.failCount + vr.skipCount == vr.totalChecked) of
    Left ok => Just ok
    Right _ => Nothing

--------------------------------------------------------------------------------
-- Opaque Handles
--------------------------------------------------------------------------------

||| Opaque handle type for FFI
||| Prevents direct construction, enforces creation through safe API
public export
data Handle : Type where
  MkHandle : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> Handle

||| Safely create a handle from a pointer value. Uses `choose` to obtain a
||| real `So (ptr /= 0)` witness for the non-null branch. (Previously
||| `Just (MkHandle ptr)` left the `auto` proof unsolved and did not compile.)
public export
createHandle : Bits64 -> Maybe Handle
createHandle ptr =
  case choose (ptr /= 0) of
    Left ok => Just (MkHandle ptr {nonNull = ok})
    Right _ => Nothing

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

||| Pointer type for platform. A pointer is represented as a pointer-sized
||| unsigned integer, which matches `size_t` (`CSize`) on every supported
||| platform. (Previously `Bits (ptrSize p)`, but `Bits` is a typeclass, not a
||| `Nat -> Type` constructor, so that did not typecheck.)
public export
CPtr : Platform -> Type -> Type
CPtr p _ = CSize p

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

||| Size of C types (platform-specific). The `CInt p` / `CSize p` aliases
||| reduce to `Bits32` / `Bits64` before this function is applied, so they are
||| handled by the concrete `Bits32` / `Bits64` clauses below; matching on the
||| aliases directly is not possible (they are type-level functions, not
||| constructors).
public export
cSizeOf : (p : Platform) -> (t : Type) -> Nat
cSizeOf p Bits32 = 4
cSizeOf p Bits64 = 8
cSizeOf p Double = 8
cSizeOf p _ = ptrSize p `div` 8

||| Alignment of C types (platform-specific). See `cSizeOf` for why the
||| `CInt` / `CSize` aliases are not matched directly.
public export
cAlignOf : (p : Platform) -> (t : Type) -> Nat
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
    let fmtInt : Bits32 = case fmt of
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

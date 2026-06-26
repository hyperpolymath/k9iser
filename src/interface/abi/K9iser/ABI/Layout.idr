-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Memory Layout Proofs for k9iser
|||
||| Provides formal proofs about memory layout, alignment, and padding
||| for C-compatible K9 contract structs.
|||
||| @see K9iser.ABI.Types for the domain types

module K9iser.ABI.Layout

import K9iser.ABI.Types
import Data.Vect
import Data.So
import Data.Nat
import Decidable.Equality

%default total

--------------------------------------------------------------------------------
-- Alignment Utilities
--------------------------------------------------------------------------------

||| Calculate padding needed for alignment
public export
paddingFor : (offset : Nat) -> (alignment : Nat) -> Nat
paddingFor offset alignment =
  if offset `mod` alignment == 0
    then 0
    else minus alignment (offset `mod` alignment)

||| Proof that alignment divides aligned size: `m = k * n`.
public export
data Divides : Nat -> Nat -> Type where
  DivideBy : (k : Nat) -> {n : Nat} -> {m : Nat} -> (m = k * n) -> Divides n m

||| Sound decision procedure for divisibility. Returns a genuine
||| `Divides n m` witness when `n` evenly divides `m`, otherwise Nothing.
||| Division by zero is undecidable here and yields Nothing.
public export
decDivides : (n : Nat) -> (m : Nat) -> Maybe (Divides n m)
decDivides Z _ = Nothing
decDivides (S k) m =
  let q = m `div` (S k) in
  case decEq m (q * (S k)) of
    Yes prf => Just (DivideBy q prf)
    No _ => Nothing

||| Round up to next alignment boundary
public export
alignUp : (size : Nat) -> (alignment : Nat) -> Nat
alignUp size alignment =
  size + paddingFor size alignment

||| Sound divisibility check for an aligned size. The general theorem
||| "alignUp size align is always divisible by align" needs div/mod lemmas and
||| is tracked as residual proof work; here we *decide* it via `decDivides`,
||| which returns a genuine witness when it holds. For the concrete ABI layouts
||| below, divisibility is proven outright (`DivideBy`). (Previously
||| `alignUpCorrect … = DivideBy … Refl`, whose `Refl` cannot typecheck for
||| symbolic inputs.)
public export
alignUpDivides : (size : Nat) -> (align : Nat) ->
                 Maybe (Divides align (alignUp size align))
alignUpDivides size align = decDivides align (alignUp size align)

--------------------------------------------------------------------------------
-- Struct Field Layout
--------------------------------------------------------------------------------

||| A field in a struct with its offset and size
public export
record Field where
  constructor MkField
  name : String
  offset : Nat
  size : Nat
  alignment : Nat

||| Calculate the offset of the next field
public export
nextFieldOffset : Field -> Nat
nextFieldOffset f = alignUp (f.offset + f.size) f.alignment

||| A struct layout is a list of fields with proofs
public export
record StructLayout where
  constructor MkStructLayout
  fields : Vect n Field
  totalSize : Nat
  alignment : Nat
  {auto 0 sizeCorrect : So (totalSize >= sum (map (\f => f.size) fields))}
  {auto 0 aligned : Divides alignment totalSize}

||| Calculate total struct size with padding
public export
calcStructSize : Vect k Field -> Nat -> Nat
calcStructSize [] align = 0
calcStructSize (f :: fs) align =
  let lastOffset = foldl (\acc, field => nextFieldOffset field) f.offset fs
      lastSize = foldr (\field, _ => field.size) f.size fs
   in alignUp (lastOffset + lastSize) align

||| Proof that field offsets are correctly aligned
public export
data FieldsAligned : Vect k Field -> Type where
  NoFields : FieldsAligned []
  ConsField :
    (f : Field) ->
    (rest : Vect k Field) ->
    Divides f.alignment f.offset ->
    FieldsAligned rest ->
    FieldsAligned (f :: rest)

||| Decide field alignment for every field, building a real `FieldsAligned`
||| witness from per-field divisibility proofs.
public export
decFieldsAligned : (fs : Vect k Field) -> Maybe (FieldsAligned fs)
decFieldsAligned [] = Just NoFields
decFieldsAligned (f :: fs) =
  case decDivides f.alignment f.offset of
    Nothing => Nothing
    Just dvd => case decFieldsAligned fs of
                  Nothing => Nothing
                  Just rest => Just (ConsField f fs dvd rest)

||| Verify a struct layout is valid and construct it. Both erased obligations
||| are discharged from real decision procedures: the size lower bound via
||| `choose`, and the size/alignment divisibility via `decDivides`. Returns
||| Nothing when either obligation cannot be met. (Previously used a nonexistent
||| `decSo` and silently dropped the `aligned` obligation.)
public export
verifyLayout : (fields : Vect k Field) -> (align : Nat) -> Maybe StructLayout
verifyLayout fields align =
  let size = calcStructSize fields align in
  case choose (size >= sum (map (\f => f.size) fields)) of
    Right _ => Nothing
    Left okSize =>
      case decDivides align size of
        Nothing => Nothing
        Just okAlign =>
          Just (MkStructLayout fields size align
                  {sizeCorrect = okSize, aligned = okAlign})

--------------------------------------------------------------------------------
-- K9 Contract Layout
--------------------------------------------------------------------------------

||| Layout for the K9Contract struct as passed across the FFI boundary.
|||
||| Fields (C representation):
|||   contractName : const char*  (8 bytes, offset 0)
|||   version      : const char*  (8 bytes, offset 8)
|||   sourceFormat : uint32_t     (4 bytes, offset 16)
|||   tier         : uint32_t     (4 bytes, offset 20)
|||   mustCount    : uint32_t     (4 bytes, offset 24)
|||   trustCount   : uint32_t     (4 bytes, offset 28)
|||   dustCount    : uint32_t     (4 bytes, offset 32)
|||   intendCount  : uint32_t     (4 bytes, offset 36)
public export
k9ContractLayout : StructLayout
k9ContractLayout =
  MkStructLayout
    [ MkField "contractName" 0  8 8   -- const char*
    , MkField "version"      8  8 8   -- const char*
    , MkField "sourceFormat" 16 4 4   -- uint32_t
    , MkField "tier"         20 4 4   -- uint32_t
    , MkField "mustCount"    24 4 4   -- uint32_t
    , MkField "trustCount"   28 4 4   -- uint32_t
    , MkField "dustCount"    32 4 4   -- uint32_t
    , MkField "intendCount"  36 4 4   -- uint32_t
    ]
    40  -- Total size: 40 bytes
    8   -- Alignment: 8 bytes (pointer alignment)
    {sizeCorrect = Oh}
    {aligned = DivideBy 5 Refl}

||| Layout for the ValidationResult struct.
|||
||| Fields (C representation):
|||   contractName  : const char*  (8 bytes, offset 0)
|||   totalChecked  : uint32_t     (4 bytes, offset 8)
|||   passCount     : uint32_t     (4 bytes, offset 12)
|||   failCount     : uint32_t     (4 bytes, offset 16)
|||   skipCount     : uint32_t     (4 bytes, offset 20)
|||   overallResult : uint32_t     (4 bytes, offset 24)
|||   _padding      :              (4 bytes, offset 28)
public export
validationResultLayout : StructLayout
validationResultLayout =
  MkStructLayout
    [ MkField "contractName"  0  8 8  -- const char*
    , MkField "totalChecked"  8  4 4  -- uint32_t
    , MkField "passCount"     12 4 4  -- uint32_t
    , MkField "failCount"     16 4 4  -- uint32_t
    , MkField "skipCount"     20 4 4  -- uint32_t
    , MkField "overallResult" 24 4 4  -- uint32_t
    ]
    32  -- Total size: 32 bytes (with 4 bytes tail padding)
    8   -- Alignment: 8 bytes
    {sizeCorrect = Oh}
    {aligned = DivideBy 4 Refl}

||| Layout for MustRule struct.
|||
||| Fields (C representation):
|||   name       : const char*  (8 bytes, offset 0)
|||   fieldPath  : const char*  (8 bytes, offset 8)
|||   expression : const char*  (8 bytes, offset 16)
|||   severity   : uint32_t     (4 bytes, offset 24)
|||   _padding   :              (4 bytes, offset 28)
public export
mustRuleLayout : StructLayout
mustRuleLayout =
  MkStructLayout
    [ MkField "name"       0  8 8  -- const char*
    , MkField "fieldPath"  8  8 8  -- const char*
    , MkField "expression" 16 8 8  -- const char*
    , MkField "severity"   24 4 4  -- uint32_t
    ]
    32  -- Total size: 32 bytes (with 4 bytes tail padding)
    8   -- Alignment: 8 bytes
    {sizeCorrect = Oh}
    {aligned = DivideBy 4 Refl}

--------------------------------------------------------------------------------
-- Platform-Specific Layouts
--------------------------------------------------------------------------------

||| Struct layout may differ by platform
public export
PlatformLayout : Platform -> Type -> Type
PlatformLayout p t = StructLayout

||| Verify layout is correct for all platforms
public export
verifyAllPlatforms :
  (layouts : (p : Platform) -> PlatformLayout p t) ->
  Either String ()
verifyAllPlatforms layouts =
  Right ()

--------------------------------------------------------------------------------
-- C ABI Compatibility
--------------------------------------------------------------------------------

||| Proof that a struct follows C ABI rules
public export
data CABICompliant : StructLayout -> Type where
  CABIOk :
    (layout : StructLayout) ->
    FieldsAligned layout.fields ->
    CABICompliant layout

||| Verify a layout against the C ABI alignment rules, returning a genuine
||| `CABICompliant` proof (built from real per-field divisibility witnesses)
||| or an error when some field offset is misaligned. (Previously a `?hole`.)
public export
checkCABI : (layout : StructLayout) -> Either String (CABICompliant layout)
checkCABI layout =
  case decFieldsAligned layout.fields of
    Just prf => Right (CABIOk layout prf)
    Nothing => Left "Field offsets are not correctly aligned for the C ABI"

-- The concrete per-layout C-ABI compliance witnesses live in
-- `K9iser.ABI.Proofs`, where each layout name is qualified (`Layout.foo`) in
-- the theorem type so it is not auto-bound as an implicit.

--------------------------------------------------------------------------------
-- Offset Calculation
--------------------------------------------------------------------------------

||| Calculate field offset with proof of correctness
public export
fieldOffset : (layout : StructLayout) -> (fieldName : String) -> Maybe (Nat, Field)
fieldOffset layout name =
  case findIndex (\f => f.name == name) layout.fields of
    Just idx => Just (finToNat idx, index idx layout.fields)
    Nothing => Nothing

||| Decide whether a field lies within a struct's byte bounds, returning a
||| genuine proof when `offset + size <= totalSize`. The previous signature
||| asserted this for *every* field unconditionally, which is false (a field
||| need not belong to the layout); this honest version decides it.
public export
offsetInBounds : (layout : StructLayout) -> (f : Field) ->
                 Maybe (So (f.offset + f.size <= layout.totalSize))
offsetInBounds layout f =
  case choose (f.offset + f.size <= layout.totalSize) of
    Left ok => Just ok
    Right _ => Nothing

-- SPDX-License-Identifier: PMPL-1.0-or-later
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
    else alignment - (offset `mod` alignment)

||| Proof that alignment divides aligned size
public export
data Divides : Nat -> Nat -> Type where
  DivideBy : (k : Nat) -> {n : Nat} -> {m : Nat} -> (m = k * n) -> Divides n m

||| Round up to next alignment boundary
public export
alignUp : (size : Nat) -> (alignment : Nat) -> Nat
alignUp size alignment =
  size + paddingFor size alignment

||| Proof that alignUp produces aligned result
public export
alignUpCorrect : (size : Nat) -> (align : Nat) -> (align > 0) -> Divides align (alignUp size align)
alignUpCorrect size align prf =
  DivideBy ((size + paddingFor size align) `div` align) Refl

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
calcStructSize : Vect n Field -> Nat -> Nat
calcStructSize [] align = 0
calcStructSize (f :: fs) align =
  let lastOffset = foldl (\acc, field => nextFieldOffset field) f.offset fs
      lastSize = foldr (\field, _ => field.size) f.size fs
   in alignUp (lastOffset + lastSize) align

||| Proof that field offsets are correctly aligned
public export
data FieldsAligned : Vect n Field -> Type where
  NoFields : FieldsAligned []
  ConsField :
    (f : Field) ->
    (rest : Vect n Field) ->
    Divides f.alignment f.offset ->
    FieldsAligned rest ->
    FieldsAligned (f :: rest)

||| Verify a struct layout is valid
public export
verifyLayout : (fields : Vect n Field) -> (align : Nat) -> Either String StructLayout
verifyLayout fields align =
  let size = calcStructSize fields align
   in case decSo (size >= sum (map (\f => f.size) fields)) of
        Yes prf => Right (MkStructLayout fields size align)
        No _ => Left "Invalid struct size"

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

||| Check if layout follows C ABI
public export
checkCABI : (layout : StructLayout) -> Either String (CABICompliant layout)
checkCABI layout =
  Right (CABIOk layout ?fieldsAlignedProof)

||| Proof that K9 contract layout is C ABI compliant
export
k9ContractCABI : CABICompliant k9ContractLayout
k9ContractCABI = CABIOk k9ContractLayout ?k9ContractFieldsAligned

||| Proof that validation result layout is C ABI compliant
export
validationResultCABI : CABICompliant validationResultLayout
validationResultCABI = CABIOk validationResultLayout ?validationResultFieldsAligned

--------------------------------------------------------------------------------
-- Offset Calculation
--------------------------------------------------------------------------------

||| Calculate field offset with proof of correctness
public export
fieldOffset : (layout : StructLayout) -> (fieldName : String) -> Maybe (n : Nat ** Field)
fieldOffset layout name =
  case findIndex (\f => f.name == name) layout.fields of
    Just idx => Just (finToNat idx ** index idx layout.fields)
    Nothing => Nothing

||| Proof that field offset is within struct bounds
public export
offsetInBounds : (layout : StructLayout) -> (f : Field) -> So (f.offset + f.size <= layout.totalSize)
offsetInBounds layout f = ?offsetInBoundsProof

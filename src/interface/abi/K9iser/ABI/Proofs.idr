-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Machine-checked proofs over the k9iser ABI.
|||
||| These are not runtime tests — they are propositional statements the Idris2
||| type checker must discharge at compile time. If any concrete ABI layout
||| were misaligned, the result-code encoding wrong, or a decision procedure
||| mis-defined, this module would fail to typecheck and the proof build would
||| go red.
|||
||| The C-ABI compliance witnesses are built directly from per-field
||| divisibility proofs (`DivideBy k Refl`, where `offset = k * alignment`).
||| Multiplication reduces during type checking, so these are fully verified by
||| the compiler; we avoid routing them through `Nat` division, which is a
||| primitive that does not reduce at the type level.

module K9iser.ABI.Proofs

import K9iser.ABI.Types
import K9iser.ABI.Layout
import Data.So
import Data.Vect

%default total

--------------------------------------------------------------------------------
-- The concrete FFI struct layouts are provably C-ABI compliant.
--------------------------------------------------------------------------------

||| Every field offset in the K9Contract layout divides its alignment:
||| 0|8, 8|8, 16|4, 20|4, 24|4, 28|4, 32|4, 36|4.
export
k9ContractCompliant : CABICompliant Layout.k9ContractLayout
k9ContractCompliant =
  CABIOk k9ContractLayout
    (ConsField _ _ (DivideBy 0 Refl)
    (ConsField _ _ (DivideBy 1 Refl)
    (ConsField _ _ (DivideBy 4 Refl)
    (ConsField _ _ (DivideBy 5 Refl)
    (ConsField _ _ (DivideBy 6 Refl)
    (ConsField _ _ (DivideBy 7 Refl)
    (ConsField _ _ (DivideBy 8 Refl)
    (ConsField _ _ (DivideBy 9 Refl)
     NoFields))))))))

||| Every field offset in the ValidationResult layout is aligned:
||| 0|8, 8|4, 12|4, 16|4, 20|4, 24|4.
export
validationResultCompliant : CABICompliant Layout.validationResultLayout
validationResultCompliant =
  CABIOk validationResultLayout
    (ConsField _ _ (DivideBy 0 Refl)
    (ConsField _ _ (DivideBy 2 Refl)
    (ConsField _ _ (DivideBy 3 Refl)
    (ConsField _ _ (DivideBy 4 Refl)
    (ConsField _ _ (DivideBy 5 Refl)
    (ConsField _ _ (DivideBy 6 Refl)
     NoFields))))))

||| Every field offset in the MustRule layout is aligned:
||| 0|8, 8|8, 16|8, 24|4.
export
mustRuleCompliant : CABICompliant Layout.mustRuleLayout
mustRuleCompliant =
  CABIOk mustRuleLayout
    (ConsField _ _ (DivideBy 0 Refl)
    (ConsField _ _ (DivideBy 1 Refl)
    (ConsField _ _ (DivideBy 2 Refl)
    (ConsField _ _ (DivideBy 6 Refl)
     NoFields))))

--------------------------------------------------------------------------------
-- Result-code round-trip: the encoding the Zig FFI depends on.
--------------------------------------------------------------------------------

||| The success code is zero, as every FFI caller assumes.
export
okIsZero : resultToInt Ok = 0
okIsZero = Refl

||| The trust-failure code is seven (the last code in the enumeration).
export
trustFailureIsSeven : resultToInt TrustFailure = 7
trustFailureIsSeven = Refl

--------------------------------------------------------------------------------
-- Safety-tier ordering: the tier levels are strictly increasing.
--------------------------------------------------------------------------------

||| Kennel is the least-powerful tier (level 0).
export
kennelIsZero : tierLevel Kennel = 0
kennelIsZero = Refl

||| The safety tiers are strictly ordered Kennel < Yard < Hunt by level.
export
tiersOrdered : So (tierLevel Kennel < tierLevel Yard &&
                   tierLevel Yard < tierLevel Hunt)
tiersOrdered = Oh

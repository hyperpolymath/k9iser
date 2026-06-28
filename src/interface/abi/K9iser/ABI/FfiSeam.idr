-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Layer 4: ABI<->FFI seam soundness proofs for k9iser.
|||
||| The structural gate (scripts/abi-ffi-gate.py) checks that the Idris `Result`
||| enum and the Zig FFI enum agree by name and value. This module supplies the
||| PROOF-SIDE guarantee that the encoding itself is SOUND:
|||
|||   (a) `resultToIntInjective` — distinct ABI outcomes never collide on the
|||       wire (the C integer unambiguously identifies the ABI value).
|||   (b) `intToResult` + `resultRoundTrip` — the encoding is faithful/lossless:
|||       decoding the wire integer recovers exactly the ABI value. Injectivity
|||       is then DERIVED from the round-trip via `justInjective`+`cong`.
|||
||| Positive controls (concrete decode = Refl) and a non-vacuity / negative
||| control (two distinct codes have distinct ints) are machine-checked below.
|||
||| k9iser defines only the `Result` FFI enum encoder (`resultToInt`); there is
||| no `ProofStatus`/`statusToInt` or other FFI enum encoder, so clause (c) of
||| the seam obligation is vacuous here.

module K9iser.ABI.FfiSeam

import K9iser.ABI.Types
import Control.Function
import Data.Maybe

%default total

--------------------------------------------------------------------------------
-- Decoder (faithful inverse of resultToInt)
--------------------------------------------------------------------------------

||| Decode a C wire integer back to a `Result`.
|||
||| Built with boolean `Bits32` equality (`==`) on concrete literals so that
||| `intToResult (resultToInt r)` reduces definitionally for each constructor,
||| letting the round-trip lemma below be proved by `Refl`.
public export
intToResult : Bits32 -> Maybe Result
intToResult x =
  if x == 0 then Just Ok
  else if x == 1 then Just Error
  else if x == 2 then Just InvalidParam
  else if x == 3 then Just OutOfMemory
  else if x == 4 then Just NullPointer
  else if x == 5 then Just ParseError
  else if x == 6 then Just ConstraintViolation
  else if x == 7 then Just TrustFailure
  else Nothing

--------------------------------------------------------------------------------
-- (b) Round-trip: the encoding is faithful / lossless
--------------------------------------------------------------------------------

||| Decoding the encoded form of any `Result` recovers exactly that `Result`.
||| This is the master soundness fact for the seam: nothing is lost on the wire.
public export
resultRoundTrip : (r : Result) -> intToResult (resultToInt r) = Just r
resultRoundTrip Ok                  = Refl
resultRoundTrip Error               = Refl
resultRoundTrip InvalidParam        = Refl
resultRoundTrip OutOfMemory         = Refl
resultRoundTrip NullPointer         = Refl
resultRoundTrip ParseError          = Refl
resultRoundTrip ConstraintViolation = Refl
resultRoundTrip TrustFailure        = Refl

--------------------------------------------------------------------------------
-- (a) Injectivity: distinct ABI outcomes never collide on the wire
--------------------------------------------------------------------------------

||| The encoding is unambiguous: equal wire integers imply equal ABI values.
||| DERIVED from the round-trip — if `resultToInt a = resultToInt b` then
||| applying `intToResult` to both sides (via `cong`) gives `Just a = Just b`,
||| and `injective` (the `Injective Just` instance) strips the `Just`. No case
||| analysis on constructors is needed; the proof rides on `resultRoundTrip`.
public export
resultToIntInjective : (a : Result) -> (b : Result) ->
                       resultToInt a = resultToInt b -> a = b
resultToIntInjective a b prf =
  injective $
    trans (sym (resultRoundTrip a)) $
    trans (cong intToResult prf) (resultRoundTrip b)

--------------------------------------------------------------------------------
-- Positive controls (concrete decodes, machine-checked = Refl)
--------------------------------------------------------------------------------

||| The wire integer 0 decodes to `Ok`.
public export
decodeOk : intToResult 0 = Just Ok
decodeOk = Refl

||| The wire integer 7 decodes to `TrustFailure` (the last code).
public export
decodeTrustFailure : intToResult 7 = Just TrustFailure
decodeTrustFailure = Refl

||| An out-of-range wire integer decodes to `Nothing` (no spurious result).
public export
decodeOutOfRange : intToResult 8 = Nothing
decodeOutOfRange = Refl

--------------------------------------------------------------------------------
-- Negative / non-vacuity control
--------------------------------------------------------------------------------

||| Two DISTINCT result codes have DISTINCT wire integers — machine-checked.
||| This rules out the vacuous reading of injectivity (where the premise could
||| never be satisfied): `Ok` and `Error` genuinely differ on the wire.
public export
okNotError : Not (resultToInt Ok = resultToInt Error)
okNotError = \case Refl impossible

||| A second distinct pair, for good measure: `OutOfMemory` (3) /= `ParseError` (5).
public export
oomNotParse : Not (resultToInt OutOfMemory = resultToInt ParseError)
oomNotParse = \case Refl impossible

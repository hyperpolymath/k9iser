-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Flagship semantic proof for k9iser: configs as self-validating K9 contracts.
|||
||| Headline property — "Wrap configs into self-validating K9 contracts":
||| a config that SATISFIES a contract provably validates, and a config that
||| VIOLATES it provably does NOT validate. The contract here is a faithful but
||| minimal "must"-rule: a named key MUST be present and its value MUST lie
||| within an inclusive numeric range.
|||
||| The proposition `Validates` has constructors ONLY for the satisfying case
||| (key present with an in-range value); there is no constructor for a missing
||| key or an out-of-range value. `decValidates` is a sound + complete decision
||| procedure returning a real `Dec`, `certify` is the certifier into the ABI's
||| `Result` code, and `certifySound` proves the certifier is faithful. Positive
||| and negative controls pin down non-vacuity.

module K9iser.ABI.Semantics

import K9iser.ABI.Types
import Data.Nat
import Decidable.Equality
import Decidable.Decidable

%default total

--------------------------------------------------------------------------------
-- Faithful domain model
--------------------------------------------------------------------------------

||| A config value. Keep the model minimal but real: configs map keys to
||| natural-number values (e.g. a port, a replica count, a timeout).
public export
Key : Type
Key = String

||| A config is an association list from keys to Nat values, as produced by a
||| parser front-end before contract checking.
public export
Config : Type
Config = List (Key, Nat)

||| A K9 "must"-contract: the key that MUST be present, and the inclusive
||| range [lo, hi] its value MUST fall within.
public export
record Contract where
  constructor MkContract
  key : Key
  lo  : Nat
  hi  : Nat

--------------------------------------------------------------------------------
-- Lookup model (resolver equation stored in the witness, per idiom 4)
--------------------------------------------------------------------------------

||| Resolve a key to its value in a config (first match wins).
public export
resolve : Key -> Config -> Maybe Nat
resolve k [] = Nothing
resolve k ((k', v) :: rest) = case decEq k k' of
  Yes _ => Just v
  No  _ => resolve k rest

||| Constructor-headed injectivity of `Just`, used to transport at the term
||| level (idiom 2) instead of casing on a stuck `resolve k c = Just v`.
justInj : {0 x, y : a} -> Just x = Just y -> x = y
justInj Refl = Refl

--------------------------------------------------------------------------------
-- The headline proposition: NO constructor for the bad case
--------------------------------------------------------------------------------

||| `InRange lo hi v` holds exactly when lo <= v AND v <= hi, using
||| propositional `LTE` (idiom 5: Nat `<=` does not reduce for symbolic
||| operands, but `LTE` is a genuine proposition).
public export
data InRange : (low, high, val : Nat) -> Type where
  MkInRange : LTE low val -> LTE val high -> InRange low high val

||| A config VALIDATES a contract iff the required key resolves to some value
||| that is in range. The witness stores the resolver equation (idiom 4), so
||| there is genuinely no way to build a `Validates` for a missing key or an
||| out-of-range value.
public export
data Validates : Contract -> Config -> Type where
  MkValidates : (v : Nat) ->
                (prf : resolve (key c) cfg = Just v) ->
                InRange (lo c) (hi c) v ->
                Validates c cfg

--------------------------------------------------------------------------------
-- Sound + complete decision for InRange
--------------------------------------------------------------------------------

||| Decide membership in an inclusive range. `isLTE` is the Prelude's complete
||| decision for `LTE`.
public export
decInRange : (lo, hi, v : Nat) -> Dec (InRange lo hi v)
decInRange lo hi v = case isLTE lo v of
  No  loBad => No (\(MkInRange loOk _) => loBad loOk)
  Yes loOk  => case isLTE v hi of
    No  hiBad => No (\(MkInRange _ hiOk) => hiBad hiOk)
    Yes hiOk  => Yes (MkInRange loOk hiOk)

--------------------------------------------------------------------------------
-- Sound + complete decision for Validates
--------------------------------------------------------------------------------

||| Decide whether a config validates a contract. Uses `with ... proof eq` so
||| the resolver equation is in scope in each branch (idiom 4), letting us both
||| build the positive witness and refute the negative branches honestly.
public export
decValidates : (c : Contract) -> (cfg : Config) -> Dec (Validates c cfg)
decValidates c cfg with (resolve (key c) cfg) proof eq
  _ | Nothing =
        -- No value resolves, so no `Validates` witness can exist.
        No (\(MkValidates v prf _) =>
              -- prf : resolve (key c) cfg = Just v; eq : ... = Nothing.
              case trans (sym prf) eq of Refl impossible)
  _ | (Just v) = case decInRange (lo c) (hi c) v of
        Yes ok => Yes (MkValidates v eq ok)
        No  bad =>
          -- Value resolves to `v` but is out of range; any witness would
          -- have to use the same `v` (idiom 3) and so an in-range proof.
          No (\(MkValidates v' prf rng) =>
                let vEq = the (v' = v) (justInj (trans (sym prf) eq)) in
                    bad (rewrite sym vEq in rng))

--------------------------------------------------------------------------------
-- Certifier into the ABI Result code + soundness
--------------------------------------------------------------------------------

||| Certify a config against a contract, producing an ABI `Result`:
||| `Ok` when it validates, `ConstraintViolation` when it does not.
public export
certify : (c : Contract) -> (cfg : Config) -> Result
certify c cfg = case decValidates c cfg of
  Yes _ => Ok
  No  _ => ConstraintViolation

||| Soundness: if the certifier reports `Ok`, the config really does validate.
public export
certifySound : (c : Contract) -> (cfg : Config) ->
               certify c cfg = Ok -> Validates c cfg
certifySound c cfg prf with (decValidates c cfg)
  certifySound c cfg prf      | Yes ok = ok
  certifySound c cfg Refl     | No _ impossible

||| Completeness: if the config validates, the certifier reports `Ok`.
public export
certifyComplete : (c : Contract) -> (cfg : Config) ->
                  Validates c cfg -> certify c cfg = Ok
certifyComplete c cfg vld with (decValidates c cfg)
  certifyComplete c cfg vld | Yes _   = Refl
  certifyComplete c cfg vld | No  bad = absurd (bad vld)

--------------------------------------------------------------------------------
-- Controls (non-vacuity)
--------------------------------------------------------------------------------

||| A concrete contract: key "replicas" must be in [1, 10].
||| Small bounds keep type-level normalisation cheap while the property stays
||| faithful (a "must"-rule: required key present, value within range).
public export
portContract : Contract
portContract = MkContract "replicas" 1 10

||| Helper: extract the `InRange` proof from the complete decision on concrete
||| operands. `decInRange 1 10 5` evaluates to `Yes ...` at type-check time, so
||| this is a genuine, machine-checked witness (not proof search).
inRangeFromDec : (low, high, val : Nat) ->
                 {auto 0 ok : IsYes (decInRange low high val)} ->
                 InRange low high val
inRangeFromDec low high val {ok} with (decInRange low high val)
  inRangeFromDec low high val {ok = ItIsYes} | Yes prf = prf

||| POSITIVE CONTROL: a config with replicas = 5 validates the contract.
||| `resolve "replicas" goodConfig` reduces to `Just 5` on concrete data
||| (idiom 5), so the equation is `Refl`.
public export
goodConfig : Config
goodConfig = [("host", 1), ("replicas", 5)]

public export
goodValidates : Validates Semantics.portContract Semantics.goodConfig
goodValidates = MkValidates 5 Refl (inRangeFromDec 1 10 5)

||| NEGATIVE CONTROL 1 (out of range): replicas = 0 violates [1, 10].
public export
badRangeConfig : Config
badRangeConfig = [("replicas", 0)]

public export
badRangeNotValidates : Not (Validates Semantics.portContract Semantics.badRangeConfig)
badRangeNotValidates (MkValidates v prf (MkInRange loOk _)) =
  -- prf : resolve "replicas" badRangeConfig = Just v, which resolves to Just 0,
  -- so justInj prf : 0 = v. Then loOk : LTE 1 v becomes LTE 1 0 (uninhabited).
  let vEq = the (0 = v) (justInj prf) in
      absurd (replace {p = LTE 1} (sym vEq) loOk)

||| NEGATIVE CONTROL 2 (missing key): no "replicas" key at all.
public export
missingConfig : Config
missingConfig = [("host", 1)]

public export
missingNotValidates : Not (Validates Semantics.portContract Semantics.missingConfig)
missingNotValidates (MkValidates v prf _) = absurd prf

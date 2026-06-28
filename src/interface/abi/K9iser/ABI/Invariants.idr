-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Layer-3 deepening proof for k9iser: the CONJUNCTION-OF-CONTRACTS law.
|||
||| The Layer-2 flagship (`K9iser.ABI.Semantics`) proves the soundness and
||| completeness of validating a config against a SINGLE K9 "must"-contract.
||| This module proves a genuinely different, deeper, algebraic property of the
||| SAME model: how validation behaves under CONJUNCTION of contracts.
|||
||| A config is a self-validating K9 contract; in practice a contract is a
||| *bundle* of must-rules, so the central question is compositional: does
||| validating a conjoined bundle decompose into validating each conjunct?
|||
||| Headline theorems (over the EXISTING `Validates` from Semantics):
|||   * `validatesAndIff`  — a config validates `c1 AND c2` IFF it validates c1
|||                          AND validates c2 (both directions, as a real iso of
|||                          witnesses, not a boolean tautology).
|||   * `validatesAllConsIff` — the n-ary version: validating `(c :: cs)`
|||                          decomposes into the head and the tail.
|||   * `decValidatesAll`  — a sound + COMPLETE decision for the n-ary form,
|||                          built compositionally from the Layer-2 decision.
|||   * `validatesAllAppend` — DISTRIBUTION of conjunction over list append:
|||                          validating `xs ++ ys` IFF validating xs and ys.
|||   * `validatesAllWeaken` — MONOTONICITY / downward-closure: a config that
|||                          validates a bundle validates every sub-bundle
|||                          reachable by dropping a contract (here: the tail).
|||
||| Plus a positive control (an inhabited witness for a concrete two-contract
||| bundle) and a negative / non-vacuity control (`Not (...)`).

module K9iser.ABI.Invariants

import K9iser.ABI.Types
import K9iser.ABI.Semantics
import Data.Nat
import Decidable.Equality
import Decidable.Decidable

%default total

--------------------------------------------------------------------------------
-- Local helpers. The model's `resolve` keys on `String`, whose `decEq` does NOT
-- reduce definitionally (idiom 5), so `resolve k cfg = Just v` cannot be proved
-- by bare `Refl` outside the defining module. We instead prove the two resolver
-- steps as genuine lemmas (`with (decEq ...)`), and build range witnesses by
-- reducing the public `decInRange` (which DOES reduce on concrete Nats).
--------------------------------------------------------------------------------

||| Constructor-headed injectivity of `Just` (idiom 3), to transport a resolved
||| equation at the term level in the negative control.
jInj : {0 x, y : a} -> Just x = Just y -> x = y
jInj Refl = Refl

||| The required key sits at the head: `resolve` returns its value. Proved by
||| `with (decEq k k)`, discharging the impossible `No` branch with reflexivity.
resolveHead : (k : Key) -> (v : Nat) -> (rest : Config) ->
              resolve k ((k, v) :: rest) = Just v
resolveHead k v rest with (decEq k k)
  resolveHead k v rest | Yes _      = Refl
  resolveHead k v rest | No  contra = absurd (contra Refl)

||| A distinct head key is skipped: `resolve` recurses into the tail. Proved by
||| `with (decEq k k')`, discharging the impossible `Yes` branch via the
||| supplied disequality.
resolveSkip : (k, k' : Key) -> Not (k = k') -> (v' : Nat) -> (rest : Config) ->
              resolve k ((k', v') :: rest) = resolve k rest
resolveSkip k k' neq v' rest with (decEq k k')
  resolveSkip k k' neq v' rest | Yes eq = absurd (neq eq)
  resolveSkip k k' neq v' rest | No  _  = Refl

||| Build an `InRange` witness on CONCRETE operands by reducing the public
||| `decInRange` (which reduces fully on concrete Nats, unlike a `with`-block on
||| `String`). The `{auto}` `IsYes` proof forces the reduction to `Yes` at
||| type-check time, so this is a genuine machine-checked witness — not proof
||| search, not a postulate.
inRangeWit : (low, high, val : Nat) ->
             {auto 0 ok : IsYes (decInRange low high val)} ->
             InRange low high val
inRangeWit low high val {ok} with (decInRange low high val)
  inRangeWit low high val {ok = ItIsYes} | Yes prf = prf

--------------------------------------------------------------------------------
-- Binary conjunction of contracts
--------------------------------------------------------------------------------

||| Conjunction of two contract-validations against the SAME config. This is a
||| genuine product of Layer-2 witnesses: to inhabit it you must independently
||| prove the config validates c1 and validates c2. It is therefore strictly
||| deeper than the single-contract `Validates`.
public export
data ValidatesBoth : (c1, c2 : Contract) -> (cfg : Config) -> Type where
  MkValidatesBoth : Validates c1 cfg ->
                    Validates c2 cfg ->
                    ValidatesBoth c1 c2 cfg

||| HEADLINE (binary), forward: validating the conjunction gives both conjuncts.
public export
validatesAndFwd : {0 c1, c2 : Contract} -> {0 cfg : Config} ->
                  ValidatesBoth c1 c2 cfg ->
                  (Validates c1 cfg, Validates c2 cfg)
validatesAndFwd (MkValidatesBoth p q) = (p, q)

||| HEADLINE (binary), backward: both conjuncts give the conjunction.
public export
validatesAndBwd : {0 c1, c2 : Contract} -> {0 cfg : Config} ->
                  (Validates c1 cfg, Validates c2 cfg) ->
                  ValidatesBoth c1 c2 cfg
validatesAndBwd (p, q) = MkValidatesBoth p q

||| HEADLINE (binary), iso: the two directions compose to the identity on the
||| pair, witnessing that `ValidatesBoth` is exactly the conjunction (no extra
||| or missing information). This `= Refl` is a real round-trip equality.
public export
validatesAndIff : {0 c1, c2 : Contract} -> {0 cfg : Config} ->
                  (pq : (Validates c1 cfg, Validates c2 cfg)) ->
                  validatesAndFwd (validatesAndBwd pq) = pq
validatesAndIff (p, q) = Refl

||| COMMUTATIVITY of conjunction: order of conjuncts does not matter.
public export
validatesBothSym : {0 c1, c2 : Contract} -> {0 cfg : Config} ->
                   ValidatesBoth c1 c2 cfg -> ValidatesBoth c2 c1 cfg
validatesBothSym (MkValidatesBoth p q) = MkValidatesBoth q p

--------------------------------------------------------------------------------
-- N-ary conjunction: validating a whole bundle of contracts
--------------------------------------------------------------------------------

||| A config validates a BUNDLE (list) of contracts iff it validates every one.
||| The empty bundle is vacuously validated; a cons requires the head to be
||| validated and the tail to be validated. This is the inductive conjunction
||| over the Layer-2 `Validates`.
public export
data ValidatesAll : (cfg : Config) -> (cs : List Contract) -> Type where
  ValidatesNil  : ValidatesAll cfg []
  ValidatesCons : Validates c cfg ->
                  ValidatesAll cfg cs ->
                  ValidatesAll cfg (c :: cs)

||| HEADLINE (n-ary), forward: validating `(c :: cs)` gives the head and tail.
public export
validatesAllConsFwd : {0 c : Contract} -> {0 cs : List Contract} ->
                      {0 cfg : Config} ->
                      ValidatesAll cfg (c :: cs) ->
                      (Validates c cfg, ValidatesAll cfg cs)
validatesAllConsFwd (ValidatesCons h t) = (h, t)

||| HEADLINE (n-ary), backward: head + tail rebuild the bundle validation.
public export
validatesAllConsBwd : {0 c : Contract} -> {0 cs : List Contract} ->
                      {0 cfg : Config} ->
                      (Validates c cfg, ValidatesAll cfg cs) ->
                      ValidatesAll cfg (c :: cs)
validatesAllConsBwd (h, t) = ValidatesCons h t

||| HEADLINE (n-ary), iso: round-trip on the cons decomposition is the identity.
public export
validatesAllConsIff : {0 c : Contract} -> {0 cs : List Contract} ->
                      {0 cfg : Config} ->
                      (ht : (Validates c cfg, ValidatesAll cfg cs)) ->
                      validatesAllConsFwd (validatesAllConsBwd ht) = ht
validatesAllConsIff (h, t) = Refl

--------------------------------------------------------------------------------
-- Sound + complete decision for the n-ary conjunction
--------------------------------------------------------------------------------

||| There is no `ValidatesAll` witness for a cons whose HEAD fails to validate.
||| Top-level refutation helper (idiom 2/3): peel the cons and discharge the
||| head with the supplied refutation.
headFails : {0 c : Contract} -> {0 cs : List Contract} -> {0 cfg : Config} ->
            Not (Validates c cfg) -> Not (ValidatesAll cfg (c :: cs))
headFails noH (ValidatesCons h _) = noH h

||| There is no `ValidatesAll` witness for a cons whose TAIL fails to validate.
tailFails : {0 c : Contract} -> {0 cs : List Contract} -> {0 cfg : Config} ->
            Not (ValidatesAll cfg cs) -> Not (ValidatesAll cfg (c :: cs))
tailFails noT (ValidatesCons _ t) = noT t

||| Decide whether a config validates an entire bundle. Built COMPOSITIONALLY
||| from the Layer-2 `decValidates`: this is the deeper structural result, since
||| it threads the single-contract decision through induction on the bundle and
||| stays both sound (a `Yes` is a real witness) and complete (a `No` is a real
||| refutation) at every step.
public export
decValidatesAll : (cfg : Config) -> (cs : List Contract) ->
                  Dec (ValidatesAll cfg cs)
decValidatesAll cfg [] = Yes ValidatesNil
decValidatesAll cfg (c :: cs) = case decValidates c cfg of
  No  noH => No (headFails noH)
  Yes h   => case decValidatesAll cfg cs of
    No  noT => No (tailFails noT)
    Yes t   => Yes (ValidatesCons h t)

--------------------------------------------------------------------------------
-- Distribution of conjunction over list append
--------------------------------------------------------------------------------

||| DISTRIBUTION (forward): validating `xs ++ ys` lets you split the validation
||| into the xs-part and the ys-part. Proved by induction on xs.
public export
validatesAllAppendFwd : {0 cfg : Config} -> (xs : List Contract) ->
                        {0 ys : List Contract} ->
                        ValidatesAll cfg (xs ++ ys) ->
                        (ValidatesAll cfg xs, ValidatesAll cfg ys)
validatesAllAppendFwd [] vall = (ValidatesNil, vall)
validatesAllAppendFwd (x :: xs) (ValidatesCons h t) =
  let (vxs, vys) = validatesAllAppendFwd xs t in
      (ValidatesCons h vxs, vys)

||| DISTRIBUTION (backward): validations of xs and ys recombine into a
||| validation of `xs ++ ys`. Proved by induction on the xs witness.
public export
validatesAllAppendBwd : {0 cfg : Config} ->
                        {0 xs, ys : List Contract} ->
                        ValidatesAll cfg xs -> ValidatesAll cfg ys ->
                        ValidatesAll cfg (xs ++ ys)
validatesAllAppendBwd ValidatesNil          vys = vys
validatesAllAppendBwd (ValidatesCons h t)   vys =
  ValidatesCons h (validatesAllAppendBwd t vys)

--------------------------------------------------------------------------------
-- Monotonicity / downward-closure
--------------------------------------------------------------------------------

||| MONOTONICITY: validating a bundle implies validating its tail (dropping a
||| conjunct can only weaken the requirement). This is the downward-closure
||| direction of the conjunction lattice.
public export
validatesAllWeaken : {0 c : Contract} -> {0 cs : List Contract} ->
                     {0 cfg : Config} ->
                     ValidatesAll cfg (c :: cs) -> ValidatesAll cfg cs
validatesAllWeaken (ValidatesCons _ t) = t

--------------------------------------------------------------------------------
-- Certifier for the n-ary conjunction + soundness/completeness into Result
--------------------------------------------------------------------------------

||| Certify a whole bundle into the ABI `Result` code: `Ok` iff every contract
||| validates, `ConstraintViolation` otherwise.
public export
certifyAll : (cfg : Config) -> (cs : List Contract) -> Result
certifyAll cfg cs = case decValidatesAll cfg cs of
  Yes _ => Ok
  No  _ => ConstraintViolation

||| Soundness: a bundle certified `Ok` really validates every contract.
public export
certifyAllSound : (cfg : Config) -> (cs : List Contract) ->
                  certifyAll cfg cs = Ok -> ValidatesAll cfg cs
certifyAllSound cfg cs prf with (decValidatesAll cfg cs)
  certifyAllSound cfg cs prf  | Yes ok = ok
  certifyAllSound cfg cs Refl | No _ impossible

||| Completeness: if a bundle validates, certification reports `Ok`.
public export
certifyAllComplete : (cfg : Config) -> (cs : List Contract) ->
                     ValidatesAll cfg cs -> certifyAll cfg cs = Ok
certifyAllComplete cfg cs vall with (decValidatesAll cfg cs)
  certifyAllComplete cfg cs vall | Yes _   = Refl
  certifyAllComplete cfg cs vall | No  bad = absurd (bad vall)

--------------------------------------------------------------------------------
-- Controls (non-vacuity)
--------------------------------------------------------------------------------

||| First concrete contract over the SAME model: key "replicas" in [1, 10].
||| (A literal-key local copy of the Layer-2 contract so the `key` projection
||| reduces inside this module; the bundle below mixes two distinct contracts.)
public export
replicasContract : Contract
replicasContract = MkContract "replicas" 1 10

||| Second concrete contract over the SAME model: key "timeout" in [1, 30].
public export
timeoutContract : Contract
timeoutContract = MkContract "timeout" 1 30

||| A single config carrying both required keys, used for the controls. Each
||| required key is placed so that `resolve` reduces on concrete data.
public export
twoConfig : Config
twoConfig = [("replicas", 5), ("timeout", 20)]

||| `"timeout"` and `"replicas"` are distinct keys (primitive String literals).
neqTimeoutReplicas : Not ("timeout" = "replicas")
neqTimeoutReplicas = \case Refl impossible

||| Witness that `twoConfig` validates the replicas contract. The resolver
||| equation comes from `resolveHead`; `inRangeWit` supplies the machine-checked
||| range proof for 5 in [1, 10].
public export
twoValidatesReplicas : Validates Invariants.replicasContract Invariants.twoConfig
twoValidatesReplicas =
  MkValidates 5 (resolveHead "replicas" 5 [("timeout", 20)]) (inRangeWit 1 10 5)

||| Witness that `twoConfig` validates the timeout contract. `resolve "timeout"`
||| skips the head ("replicas", via `resolveSkip`) then matches ("timeout", via
||| `resolveHead`); the two steps compose with `trans`.
public export
twoValidatesTimeout : Validates Invariants.timeoutContract Invariants.twoConfig
twoValidatesTimeout =
  MkValidates 20
    (trans (resolveSkip "timeout" "replicas" neqTimeoutReplicas 5 [("timeout", 20)])
           (resolveHead "timeout" 20 []))
    (inRangeWit 1 30 20)

||| POSITIVE CONTROL (binary): `twoConfig` validates the conjunction.
public export
twoValidatesBoth : ValidatesBoth Invariants.replicasContract
                                 Invariants.timeoutContract Invariants.twoConfig
twoValidatesBoth = MkValidatesBoth twoValidatesReplicas twoValidatesTimeout

||| POSITIVE CONTROL (n-ary): `twoConfig` validates the BUNDLE
||| `[replicasContract, timeoutContract]`.
public export
twoValidatesBundle : ValidatesAll Invariants.twoConfig
                       [Invariants.replicasContract, Invariants.timeoutContract]
twoValidatesBundle =
  ValidatesCons twoValidatesReplicas
    (ValidatesCons twoValidatesTimeout ValidatesNil)

||| NEGATIVE / NON-VACUITY CONTROL: a config satisfying the replicas contract
||| but NOT the timeout contract (timeout = 99 is out of [1, 30]) does NOT
||| validate the conjunction. This rules out a vacuous `ValidatesAll`/`Both`.
public export
mixedConfig : Config
mixedConfig = [("timeout", 99), ("replicas", 5)]

||| `timeout = 99` is out of range [1, 30]. `resolveHead` pins
||| `resolve "timeout" mixedConfig = Just 99`; composing with the witness's own
||| equation and `jInj` yields `99 = v` (idiom 3); then `LTE v 30` becomes the
||| uninhabited `LTE 99 30`.
timeoutFailsMixed : Not (Validates Invariants.timeoutContract Invariants.mixedConfig)
timeoutFailsMixed (MkValidates v prf (MkInRange _ hiOk)) =
  let resolved = the (resolve "timeout" Invariants.mixedConfig = Just 99)
                     (resolveHead "timeout" 99 [("replicas", 5)])
      vEq = the (99 = v) (jInj (trans (sym resolved) prf)) in
      absurd (replace {p = \w => LTE w 30} (sym vEq) hiOk)

||| NEGATIVE CONTROL (binary): `mixedConfig` does not validate the conjunction,
||| because the timeout conjunct fails.
public export
mixedNotBoth : Not (ValidatesBoth Invariants.replicasContract
                                  Invariants.timeoutContract Invariants.mixedConfig)
mixedNotBoth (MkValidatesBoth _ vt) = timeoutFailsMixed vt

||| NEGATIVE CONTROL (n-ary): `mixedConfig` does not validate the bundle
||| `[replicasContract, timeoutContract]`, because the tail (timeout) fails.
public export
mixedNotBundle : Not (ValidatesAll Invariants.mixedConfig
                        [Invariants.replicasContract, Invariants.timeoutContract])
mixedNotBundle (ValidatesCons _ (ValidatesCons vt _)) = timeoutFailsMixed vt

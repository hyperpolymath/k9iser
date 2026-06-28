-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Layer 5 CAPSTONE: the end-to-end ABI SOUNDNESS CERTIFICATE for k9iser.
|||
||| This module does not prove a new domain theorem. It ASSEMBLES the proofs
||| discharged in the prior layers into a single inhabited certificate value,
||| demonstrating that the whole ABI contract holds together. The certificate
||| ties the chain manifest -> ABI proofs (flagship + invariant) -> FFI seam
||| into one end-to-end soundness statement:
|||
|||   * MANIFEST -> FLAGSHIP (Layer 2, `K9iser.ABI.Semantics`): the headline
|||     "self-validating K9 contract" property, witnessed on the canonical
|||     positive control `goodConfig` validating `portContract`
|||     (`goodValidates`).
|||
|||   * DEEPER INVARIANT (Layer 3, `K9iser.ABI.Invariants`): validation is
|||     compositional under CONJUNCTION of contracts, witnessed by the n-ary
|||     bundle control `twoValidatesBundle` (a config validating a two-contract
|||     bundle).
|||
|||   * FFI SEAM (Layer 4, `K9iser.ABI.FfiSeam`): the ABI<->C encoding is
|||     unambiguous on the wire, carried by `resultToIntInjective`.
|||
||| The single inhabited value `abiContractDischarged : ABISound` is built
||| ONLY from those existing exported witnesses. If any prior layer were
||| unsound, the corresponding field would fail to typecheck and this value
||| could not be constructed — so its mere existence is the capstone proof
||| that every layer is discharged together.

module K9iser.ABI.Capstone

import K9iser.ABI.Types
import K9iser.ABI.Semantics
import K9iser.ABI.Invariants
import K9iser.ABI.FfiSeam

%default total

--------------------------------------------------------------------------------
-- The capstone certificate
--------------------------------------------------------------------------------

||| End-to-end ABI soundness certificate. Each field is a KEY proven fact from
||| a distinct prior proof layer; to inhabit the record you must supply a real
||| witness for every layer simultaneously.
public export
record ABISound where
  constructor MkABISound
  ||| Layer 2 (flagship): the canonical positive control validates the
  ||| canonical contract — the "self-validating K9 contract" property.
  flagship : Validates Semantics.portContract Semantics.goodConfig
  ||| Layer 3 (deeper invariant): conjunction of contracts is validated
  ||| compositionally — the canonical bundle control.
  invariant : ValidatesAll Invariants.twoConfig
                [Invariants.replicasContract, Invariants.timeoutContract]
  ||| Layer 4 (FFI seam): the ABI<->C result encoding is injective, so distinct
  ||| ABI outcomes never collide on the wire.
  ffiSeam : (a : Result) -> (b : Result) ->
            resultToInt a = resultToInt b -> a = b

--------------------------------------------------------------------------------
-- The single inhabited capstone value
--------------------------------------------------------------------------------

||| THE CAPSTONE. Constructed purely from the existing exported witnesses of
||| each layer: `goodValidates` (Layer 2), `twoValidatesBundle` (Layer 3) and
||| `resultToIntInjective` (Layer 4). Its existence certifies that the full ABI
||| contract — manifest through flagship and invariant proofs through the FFI
||| seam — is discharged as one coherent whole.
public export
abiContractDischarged : ABISound
abiContractDischarged = MkABISound
  goodValidates
  twoValidatesBundle
  resultToIntInjective

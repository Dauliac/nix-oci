## Why

Every predicate-carrying proposal in the exploration roadmap (SLSA v1.1, OpenVEX, SCAI, zero-CVE claims) emits a signed in-toto Statement with a different predicate URI. Without a shared wrapper, each step would independently build the Statement JSON, resolve the pushed image digest, call `cosign attest`, and attach the resulting envelope as an OCI referrer. That is four steps reimplementing the same shape.

## What Changes

- Add a shared library `nix/modules/oci/lib/mkAttestation.nix` that exposes `mkAttestation { predicateType, predicate, subject }`:
  - builds a valid in-toto Statement JSON (v1 or v0.1 selectable) with `subject[].digest.sha256 = <digest>`, `predicateType = <uri>`, `predicate = <attrset>`
  - invokes `cosign attest --predicate <file> --type <uri> --new-bundle-format <ref>` (via cosign 3.0.6, pinned in flake.nix)
  - hands the resulting attestation to `mkAttachReferrer` from `oci-attach-referrer-substrate` so it lands as an OCI referrer with `artifactType = application/vnd.dev.sigstore.bundle.v0.3+json`
  - emits `NIX_OCI_ATTESTATION type=<uri> digest=<sha256>` on stdout for downstream consumers
- Register a predicate-type option surface `oci.pipeline.attestations.predicateTypes = { <name> = "<uri>"; }` (open attrset) so downstream steps register their type without editing this library.
- BDD test that a fake predicate emitted via `mkAttestation` is (a) verifiable with `cosign verify-attestation --type <uri>` and (b) discoverable via `oras discover` as a referrer.
- Docs: new `docs/content/architecture/in-toto-attestations.md`.

## Capabilities

### New Capabilities
- `supply-chain/in-toto-attestations`: shared in-toto Statement construction, signing via cosign, and referrer attachment for any predicate type.

### Modified Capabilities
- `supply-chain/oci-referrers`: adds `attestation` as a first-class user of the referrer-attach substrate; documents the `artifactType` value carried on referrers whose payload is a sigstore bundle.

## Impact

- Depends on `oci-attach-referrer-substrate` landing first (uses `mkAttachReferrer`).
- Unblocks the four downstream predicate changes (`slsa-provenance-predicate`, `openvex-authoring`, `scai-provenance-and-zero-cve-claim`, and implicitly future SPDX 3.0 / SCAI extensions).
- Cosign 3.0.6 default output is protobuf bundle, aligning with `sigstore-bundle-format`; if that change has not landed, this wrapper still opts into bundle output explicitly via `--new-bundle-format`.
- No new runtime dependency: cosign 3.0.6 already in nixpkgs pin.

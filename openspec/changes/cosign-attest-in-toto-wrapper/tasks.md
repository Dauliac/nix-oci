## 1. Library

- [ ] 1.1 Create `nix/modules/oci/lib/mkAttestation.nix` exporting `mkAttestation { predicateType, predicate, subject }` that builds an in-toto v1 Statement JSON, invokes `cosign attest --predicate <file> --type <uri> --new-bundle-format`, and hands the bundle to `mkAttachReferrer`; verify with a synthetic predicate that the emitted file is a valid sigstore bundle (parseable by `cosign verify-attestation` or `sigstore-python`)
- [ ] 1.2 Emit stdout marker `NIX_OCI_ATTESTATION type=<uri> digest=<sha256>`; verify grep matches after a synthetic attest cycle

## 2. Predicate-type registry

- [ ] 2.1 Add `oci.pipeline.attestations.predicateTypes` as an open attrset option in a new file `nix/modules/oci/pipeline/attestations.nix`; verify with `nix eval` that user contributions merge
- [ ] 2.2 Document the registry contract (attr name -> URI mapping) in the accompanying architecture doc; verify by cross-referencing from `mkAttestation` docstring

## 3. Documentation

- [ ] 3.1 Write `docs/content/architecture/in-toto-attestations.md` covering the Statement envelope, the predicate registry, and the bundle format; verify by rendering the docs site locally

## 4. BDD test

- [ ] 4.1 Add `nix/modules/oci/containers/_tests/provenance/attestation-wrapper.test.nix` with a synthetic predicate: attest, attach, discover via `oras discover`, verify via `cosign verify-attestation`; verify all scenarios pass in VM harness

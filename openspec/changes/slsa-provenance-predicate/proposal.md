## Why

Current signing binds a signature to an image digest but says nothing about how the image was built. A consumer cannot distinguish an image built from a locked flake input set on a hardened CI runner from one built from a dirty local tree by an unknown user. SLSA v1.1 provenance is the standards-track answer: a signed in-toto Statement whose predicate describes `buildDefinition.externalParameters` (flake ref, subflake, args), `buildDefinition.resolvedDependencies` (locked `flake.lock` inputs with their content hashes), and `runDetails.builder.id` (CI or user identity).

Nix is uniquely well-placed to emit truthful SLSA provenance because `flake.lock` is already a complete, content-addressed input manifest. What is missing is (a) a predicate emitter, (b) a shared attest wrapper, and (c) a way to bind the pushed digest as the Statement `subject`. Items (b) and (c) are delivered by `cosign-attest-in-toto-wrapper` and `oci-attach-referrer-substrate` respectively.

## What Changes

- New library `nix/modules/oci/security/provenance/slsa/lib.nix`:
  - `mkSlsaPredicate { flakeLockPath, flakeRef, subflakePath, builderId, buildStartedOn, buildFinishedOn }` returns a JSON attrset conforming to `https://slsa.dev/provenance/v1`.
  - Reads `flake.lock`, converts each locked input into a `resolvedDependencies[]` entry (`uri`, `digest.sha256`), sets `externalParameters.flakeRef`, `runDetails.builder.id`.
- New per-container option tree `nix/modules/oci/_oci/provenance/slsa/`:
  - `enabled.nix` (bool, default false; opt-in until CI runner identity is configured)
  - `builder-id.nix` (string; default derived from `oci.pipeline.builder` if set, else assertion)
  - `predicate-type.nix` (string; default `"https://slsa.dev/provenance/v1"`)
- Register pipeline step `provenance/slsa-attest` in `nix/modules/oci/pipeline/step-registrations.nix` (`phase = "post-push"`, `category = "provenance"`, `deps = [ "push" ]`).
- The step calls `mkAttestation` from `cosign-attest-in-toto-wrapper` with the generated predicate.
- BDD test `nix/modules/oci/containers/_tests/provenance/slsa.test.nix` verifying (a) predicate JSON schema validity, (b) `subject.digest.sha256` matches the pushed digest, (c) `slsa-verifier verify-image --provenance-path <bundle> --source-uri <flake-ref>` succeeds.
- Docs: `docs/content/how-to/slsa-provenance.md` walking through wiring the builder identity and consuming the attestation via `cosign verify-attestation` and `slsa-verifier`.

## Capabilities

### New Capabilities
- `supply-chain/slsa-provenance`: SLSA v1.1 build-provenance predicate emission from Nix flake state, signed as an in-toto attestation and attached as an OCI referrer.

### Modified Capabilities
- `supply-chain/in-toto-attestations`: registers `slsa` as a first-class predicate type via `oci.pipeline.attestations.predicateTypes.slsa`.

## Impact

- Depends on `cosign-attest-in-toto-wrapper` (shared attest wrapper) and `oci-attach-referrer-substrate` (referrer attach) landing first.
- No new tool dependency; cosign 3.0.6 emits the predicate; optional `slsa-verifier` for verification-side testing (available in nixpkgs).
- SLSA level reachable: L1 by construction (reproducible, all inputs in `flake.lock`); L2 when the builder identity is a CI keyless-signed cosign identity; L3 gated on isolated key material (documented in the how-to, not enforced here).
- Predicate byte-size is small (a few KB per referrer); no meaningful registry storage impact.

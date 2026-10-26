## Purpose

Emit a SLSA v1.1 build-provenance predicate derived from Nix flake state (locked inputs, flake ref, builder identity), sign it as an in-toto attestation via the shared cosign wrapper, and attach it as an OCI referrer of the pushed image, so consumers can verify the image came from an expected builder invoked with expected inputs.

## ADDED Requirements

### Requirement: Predicate JSON conforms to SLSA v1.1

The system SHALL emit a JSON attrset conforming to the SLSA v1.1 provenance predicate schema (`https://slsa.dev/provenance/v1`), with all required fields present.

#### Scenario: Predicate validates
- **WHEN** the emitter runs against a project's `flake.lock` and produces a predicate
- **THEN** the JSON validates against the SLSA v1.1 provenance JSON schema and contains non-empty `buildDefinition.externalParameters`, `buildDefinition.resolvedDependencies`, and `runDetails.builder.id`.

### Requirement: Resolved dependencies from flake.lock

The predicate `buildDefinition.resolvedDependencies` SHALL contain one entry per locked input in `flake.lock`, each with `uri` and `digest.sha256` derived from the lock entry's `narHash` or equivalent.

#### Scenario: Single nixpkgs input produces one entry
- **WHEN** `flake.lock` locks `nixpkgs` at a specific revision
- **THEN** `resolvedDependencies` contains an entry with `uri` matching the input source and `digest.sha256` matching the lock content hash.

### Requirement: Subject binds the pushed digest

The signed Statement's `subject[0].digest.sha256` SHALL equal the digest emitted by the push step, so `slsa-verifier` can bind the attestation to the image.

#### Scenario: slsa-verifier accepts the attestation
- **WHEN** the attestation has been attached to a pushed image and `slsa-verifier verify-image` is invoked with the expected source URI
- **THEN** the verifier reports success and prints the resolved builder identity.

### Requirement: Predicate type registration

The system SHALL register `slsa` in the predicate-type registry from `supply-chain/in-toto-attestations` with value `"https://slsa.dev/provenance/v1"`.

#### Scenario: Registry entry present
- **WHEN** the SLSA feature is enabled
- **THEN** `oci.pipeline.attestations.predicateTypes.slsa == "https://slsa.dev/provenance/v1"`.

### Requirement: Opt-in default

SLSA emit SHALL default to disabled (`oci.container.provenance.slsa.enabled = false`), because it requires the operator to configure a builder identity that is stable across builds; when a builder identity is not configured, enabling SLSA MUST fail at eval time with an actionable message.

#### Scenario: Enabling without a builder identity fails cleanly
- **WHEN** `oci.container.provenance.slsa.enabled = true` and no `builderId` is set (directly or via `oci.pipeline.builder`)
- **THEN** the build fails at eval time with a message explaining how to set the builder identity.

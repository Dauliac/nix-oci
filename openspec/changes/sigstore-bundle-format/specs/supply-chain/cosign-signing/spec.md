## Purpose

Sign container images and attestations via cosign with a selectable output format (sigstore protobuf bundle by default, detached artifacts retained for legacy consumers), so downstream verifiers using modern sigstore libraries can validate signatures without a format-conversion shim.

## ADDED Requirements

### Requirement: Selectable signature output format

The system SHALL expose a per-container option that selects between `"bundle"` (sigstore protobuf bundle, single `.sigstore.json` file) and `"detached"` (classic `.sig` + `.pem` + Rekor entry) as the cosign output format. The default SHALL be `"bundle"`.

#### Scenario: Bundle format is the default
- **WHEN** a container is signed without an explicit `bundleFormat` value
- **THEN** the emitted artifact is a `.sigstore.json` bundle and validates as a sigstore bundle.

#### Scenario: Detached format still available
- **WHEN** `oci.container.signing.cosign.bundleFormat = "detached"`
- **THEN** the emitted artifacts are the classic detached `.sig` + `.pem` pair and Rekor entry.

### Requirement: Bundle interoperability with modern verifier tooling

The emitted bundle SHALL be verifiable via `cosign verify --new-bundle-format`, `sigstore-python`, and `gh attestation verify` without a conversion step.

#### Scenario: gh attestation verify accepts the bundle
- **WHEN** a signed image is pulled and its bundle is fetched
- **THEN** `gh attestation verify <image-ref> --bundle <path.sigstore.json>` returns success and reports the expected subject and identity.

### Requirement: Cosign flag propagation

Every cosign invocation site in the tree (image sign, attestation sign, blob sign) SHALL respect the selected format option.

#### Scenario: Attestation sign inherits the format
- **WHEN** `bundleFormat = "bundle"` and an attestation is created
- **THEN** the attestation file is a sigstore bundle in the same shape as an image signature bundle.

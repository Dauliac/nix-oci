## Purpose

Construct valid in-toto Statements, sign them via cosign, and attach them as OCI referrers, providing a single shared substrate for every predicate-carrying attestation (SLSA provenance, OpenVEX, SCAI, zero-CVE claims, and future predicate types).

## ADDED Requirements

### Requirement: Build a valid in-toto Statement

The system SHALL provide a build-time function that, given a predicate type URI, a predicate attrset, and a subject descriptor, returns a valid in-toto Statement JSON conforming to `https://in-toto.io/Statement/v1`.

#### Scenario: Statement conforms to the in-toto schema
- **WHEN** the function is invoked with `predicateType = "https://slsa.dev/provenance/v1"`, a valid SLSA predicate attrset, and a subject digest
- **THEN** the returned JSON has fields `_type`, `subject`, `predicateType`, `predicate`; validates against the in-toto v1 Statement schema; and `subject[0].digest.sha256` equals the passed digest.

### Requirement: Sign the Statement via cosign

The system SHALL invoke `cosign attest` (or `cosign attest-blob` where appropriate) with the Statement as the predicate and produce a sigstore protobuf bundle as output.

#### Scenario: Bundle output is a valid sigstore bundle
- **WHEN** the sign operation completes
- **THEN** the output file is a valid sigstore bundle parseable by `cosign verify-attestation --new-bundle-format` and by `sigstore-python`.

### Requirement: Attach the signed attestation as a referrer

The system SHALL hand the signed bundle to the referrer-attach substrate so it lands as an OCI referrer of the subject image with `artifactType = "application/vnd.dev.sigstore.bundle.v0.3+json"`.

#### Scenario: Attestation is discoverable
- **WHEN** the attestation has been attached
- **THEN** `oras discover <image-ref>` lists the attestation with the correct artifact type, and `cosign verify-attestation --type <predicate-uri>` succeeds against the pushed image.

### Requirement: Predicate-type registry

The system SHALL expose an open attribute-set registry so that downstream steps register their predicate types without editing this library.

#### Scenario: Downstream step registers a new predicate type
- **WHEN** a new step contributes `oci.pipeline.attestations.predicateTypes.slsa = "https://slsa.dev/provenance/v1"`
- **THEN** the registry contains that entry and the wrapper resolves `type "slsa"` to that URI.

### Requirement: Stdout marker for downstream consumers

The signed-attestation step SHALL emit `NIX_OCI_ATTESTATION type=<uri> digest=<sha256>` on stdout so that composite pipelines can correlate attestations with the image.

#### Scenario: Marker present on success
- **WHEN** the wrapper completes an attest+attach cycle successfully
- **THEN** stdout contains exactly one line matching the marker format above.

## Purpose

Emit SBOMs via syft with a pinnable output schema version, so downstream consumers (VEX cross-reference, GUAC ingest, attestation signing) can rely on a stable, explicit contract rather than syft's silently-drifting default.

## ADDED Requirements

### Requirement: Pinned CycloneDX schema version

The system SHALL pin the emitted CycloneDX schema version via a per-container option, defaulting to `"1.6"` and accepting `"1.5"` for legacy consumers.

#### Scenario: Default emit is CycloneDX 1.6
- **WHEN** a container is built with no explicit SBOM version option
- **THEN** the syft invocation includes `-o cyclonedx-json@1.6=<path>` and the emitted JSON has `specVersion == "1.6"`.

#### Scenario: Legacy pin is honoured
- **WHEN** `oci.container.sbom.syft.specVersion = "1.5"`
- **THEN** the emitted JSON has `specVersion == "1.5"` and does not contain 1.6-only fields.

### Requirement: Cryptographic-asset components surface when present

When the container closure includes cryptographic tooling (TLS libraries, SSH, JOSE, PGP) and CycloneDX 1.6 is selected, the emitted SBOM SHALL include at least one component whose `type == "cryptographic-asset"` describing that tooling.

#### Scenario: OpenSSL closure produces a crypto-asset component
- **WHEN** an image with an `openssl` closure is scanned and emit is 1.6
- **THEN** the SBOM contains at least one component with `type == "cryptographic-asset"` referencing an OpenSSL algorithm or protocol.

### Requirement: SPDX 3.0 emit deferred to upstream

The system SHALL scaffold a `spdxVersion` option surface but MUST assert clearly when SPDX 3.0 is requested until syft upstream ships SPDX 3.0 emit.

#### Scenario: SPDX 3.0 request fails with actionable message
- **WHEN** `oci.container.sbom.syft.spdxVersion = "3.0"` on a version of syft that does not emit SPDX 3.0
- **THEN** the build fails at eval time with a message pointing to the upstream tracking issue.

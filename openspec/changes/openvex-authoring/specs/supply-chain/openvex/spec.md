## Purpose

Author OpenVEX 0.2.0 vulnerability-exploitability-exchange documents from Nix module config, consume them at scanner time to suppress non-affected findings, and attach them as signed in-toto attestations for downstream verifier consumption, so maintainers can document non-exploitability once and have every consumer honour it.

## ADDED Requirements

### Requirement: Authoring DSL

The system SHALL expose a build-time function that, given an `author` field and a list of statement attrsets, returns valid OpenVEX 0.2.0 JSON-LD.

#### Scenario: Statement with not_affected status validates
- **WHEN** the function is called with `{ author = "..."; statements = [ { vulnerability = "CVE-2025-1234"; products = [ "pkg:oci/..." ]; status = "not_affected"; justification = "vulnerable_code_not_in_execute_path"; } ]; }`
- **THEN** the returned JSON validates against the OpenVEX 0.2.0 JSON schema and has a `@context` of `https://openvex.dev/ns/v0.2.0`.

### Requirement: Path-or-attrset input

The system SHALL accept both filesystem paths and attrsets in `oci.container.vex.documents`, running attrsets through the authoring DSL and treating paths as pre-authored VEX documents to include verbatim.

#### Scenario: Mixed inputs merge cleanly
- **WHEN** `documents = [ ./vex/openssl.json { author = "..."; statements = [...]; } ]`
- **THEN** both documents are present in the effective VEX set consumed by scanners and attach steps.

### Requirement: Scanner suppression

The trivy, grype, and OSV-Scanner CVE steps SHALL accept the emitted VEX documents via their native `--vex` / `--openvex` flags and MUST suppress findings whose vulnerability ID has a `not_affected` or `fixed` statement in the effective VEX set.

#### Scenario: Not-affected CVE does not fail trivy
- **WHEN** trivy scans an image with a VEX statement marking `CVE-2025-1234` as `not_affected`
- **THEN** trivy exits zero and the CVE does not appear in the pipeline failure output.

### Requirement: Attach VEX as a signed attestation

The system SHALL attach the aggregated VEX document as an OCI referrer with `artifactType = "application/vnd.openvex+json"`, signed via the shared in-toto attestation wrapper.

#### Scenario: VEX discoverable as a referrer
- **WHEN** VEX authoring is enabled and the image has been pushed
- **THEN** `oras discover <image-ref>` lists an entry with `artifactType == "application/vnd.openvex+json"` and `cosign verify-attestation --type https://openvex.dev/ns/v0.2.0` succeeds.

### Requirement: Predicate type registration

The system SHALL register `openvex` in the predicate-type registry from `supply-chain/in-toto-attestations`.

#### Scenario: Registry entry present
- **WHEN** the VEX feature is enabled
- **THEN** the predicate-type registry contains an `openvex` entry pointing at the OpenVEX namespace URI.

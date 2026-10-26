## Purpose

Emit GitHub-native SLSA v1.0 provenance attestations from a publish workflow, keyed to the GitHub Actions workflow identity via a short-lived Sigstore certificate, so consumers with only the `gh` CLI can verify the image came from the expected repository and workflow.

## ADDED Requirements

### Requirement: Publish workflow attaches attestations

The publish workflow (or a dedicated attest workflow) SHALL invoke `actions/attest-build-provenance` on every pushed image digest, with `push-to-registry: true` and the required `id-token` / `attestations` permissions.

#### Scenario: Push produces a GitHub attestation
- **WHEN** the workflow completes a push of an image
- **THEN** `gh attestation list --repo <owner>/<repo>` returns an attestation entry for that image digest.

### Requirement: Consumer can verify with gh CLI

The attestation SHALL be verifiable via `gh attestation verify --repo <owner>/<repo> oci://<image-ref>` with no additional Sigstore infrastructure.

#### Scenario: Consumer verifies successfully
- **WHEN** a consumer with `gh` >= 2.60 and read access to the repository invokes `gh attestation verify` against a pushed image
- **THEN** the CLI reports success and prints the signing workflow identity.

### Requirement: Reuse the shared pushed-digest marker

The workflow step SHALL derive the subject digest from the `NIX_OCI_PUSHED_DIGEST` marker emitted by the push step, so the digest capture path is shared with all other provenance-attach steps.

#### Scenario: Multiple attestations bind to the same digest
- **WHEN** both `github-artifact-attestations` and `slsa-provenance-predicate` are enabled
- **THEN** both attestations reference the same subject digest and coexist as separate referrers of the image.

### Requirement: No-op when not on GitHub Actions

The change SHALL have no build-time effect and no eval-time failure when the pipeline runs outside GitHub Actions.

#### Scenario: Local build is unaffected
- **WHEN** a developer runs the pipeline on their laptop
- **THEN** no attestation is emitted, no workflow step is invoked, and the build succeeds identically to the pre-change behavior.

## Purpose

Attach signed blobs (signatures, attestations, SBOMs, VEX documents, policy artifacts) as OCI referrers of a pushed image manifest, so that downstream consumers can discover them via the distribution-spec 1.1 referrers API without relying on tag-mangling conventions.

## ADDED Requirements

### Requirement: Attach a blob as an OCI referrer of a pushed image

The system SHALL expose a build-time function that, given a pushed image reference, an artifact type, a media type, and a blob file, attaches the blob to the image manifest as an OCI referrer using `oras attach`.

#### Scenario: Referrer becomes discoverable via the referrers API
- **WHEN** the function is invoked with a valid image reference and a blob of type `application/vnd.example.sbom+json`
- **THEN** a subsequent `GET /v2/<name>/referrers/<digest>?artifactType=application/vnd.example.sbom+json` against the target registry returns a manifest list containing the attached blob's descriptor.

#### Scenario: Referrer digest is echoed on stdout for downstream steps
- **WHEN** the function completes successfully
- **THEN** the stdout stream contains a line matching `NIX_OCI_REFERRER=sha256:<64-hex-chars>` identifying the attached referrer's digest.

### Requirement: Capture the pushed image digest for later attach steps

The push step SHALL emit the digest of the freshly-pushed image on stdout in a machine-parsable form so that subsequent attach steps can bind the correct subject.

#### Scenario: Digest is emitted after every successful push
- **WHEN** the push step successfully pushes an image (any backend)
- **THEN** the stdout stream contains a line matching `NIX_OCI_PUSHED_DIGEST=sha256:<64-hex-chars>`.

### Requirement: Registry compatibility

The system SHALL work against any registry conforming to distribution-spec 1.1 (GHCR, ECR, ACR, GAR, Docker Hub, zot, Harbor 2.8+) and SHALL degrade gracefully with a documented tag-schema fallback against pre-1.1 registries.

#### Scenario: Compatible registry accepts the attach
- **WHEN** attaching against a registry advertising `OCI-Filters-Applied: artifactType` in its referrers response
- **THEN** the attach succeeds without error and the referrer is retrievable server-side.

#### Scenario: Pre-1.1 registry falls back cleanly
- **WHEN** attaching against a registry that does not implement the referrers API
- **THEN** the attach either falls back to the tag-schema `<subject-digest>.<artifactType-hash>` or fails with a clear diagnostic naming the registry and pointing to the compatibility matrix in the docs.

### Requirement: Pipeline step registration

The system SHALL register the attach operation as a first-class pipeline step under the `provenance` category, phase `post-push`, depending on the `push` step.

#### Scenario: Step appears in the pipeline gate
- **WHEN** any downstream provenance step is enabled
- **THEN** the pipeline gate includes the `provenance/referrer-attach` step and orders it after `push`.

### Requirement: Extend the pipeline category enum

The system SHALL extend the pipeline step-spec `category` enum to include `provenance`, so that this and future provenance-category steps validate.

#### Scenario: New category validates
- **WHEN** a pipeline step is registered with `category = "provenance"`
- **THEN** `openspec validate` and the pipeline gate accept the registration without a schema error.

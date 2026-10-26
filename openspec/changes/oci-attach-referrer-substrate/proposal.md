## Why

The exploration report `openspec/exploration/container-frontier-2026.md` identifies that at least eight future proposals (SLSA v1.1, OpenVEX, sigstore bundles, SCAI, GUAC, zero-CVE claims, Tetragon policy, in-toto attestations of any kind) all need to attach a signed blob as an OCI referrer to a pushed image manifest. Today `nix/modules/oci/security/signing/lib.nix` only calls `cosign sign` and no code in-tree invokes `oras attach`, computes referrer digests, or wires the `subject` relationship. Every downstream provenance proposal would reinvent this glue. Building it once, first, unblocks the entire supply-chain roadmap.

Additionally, nix2container (pinned at `nlewo/nix2container@76be960`) does not emit OCI image-spec 1.1 manifests today: no `Subject`, `ArtifactType`, or v1.1 `SchemaVersion` in `nix/image.go` or `types/types.go`. Rather than block on an upstream patch (a 2+ week detour), the post-hoc `oras attach` path works against either v1.0 or v1.1 base images and is compatible with GHCR, ECR, ACR, GAR, Docker Hub, zot, and Harbor 2.8+.

## What Changes

- Add `oras` CLI to `nix/modules/oci/packages/` (new `oras.nix`).
- Add a new shared library `nix/modules/oci/lib/mkAttachReferrer.nix` that exposes `mkAttachReferrer { imageRef, artifactType, mediaType, blob }` and emits an `oras attach` invocation plus a `NIX_OCI_REFERRER=<digest>` marker on stdout.
- Extend the closed enum in `nix/modules/oci/pipeline/_step-spec.nix` `category` with `"provenance"` and add a new `phase` value `"post-push"` if not already present.
- Teach `nix/modules/oci/internal/packages/push.nix` (and the turbo push variant) to emit `NIX_OCI_PUSHED_DIGEST=<sha256>` on stdout after every successful push so downstream referrer steps can bind the correct `subject.digest`.
- Register a first-class pipeline step `provenance/referrer-attach` in `nix/modules/oci/pipeline/step-registrations.nix` (phase `post-push`, category `provenance`, depends on `push`).
- BDD test under `nix/modules/oci/containers/_tests/provenance/referrer-attach.test.nix` verifying that `GET /v2/<name>/referrers/<digest>` returns the attached blob with the expected `artifactType`.
- Doc: new `docs/content/architecture/supply-chain-attach.md` explaining the attach substrate and the `oras attach` vs upstream nix2container-1.1 trade-off.
- Fix wrong claim in `/home/juliendauliac/.claude/projects/-home-juliendauliac-ghq-github-com-Dauliac-nix-oci/memory/MEMORY.md` (line "`cosign attest` with SBOM predicate is available") is out of scope for this change; tracked in `supply-chain-ecosystem-docs`.

## Capabilities

### New Capabilities
- `supply-chain/oci-referrers`: attaching signed blobs as OCI referrers of a pushed image, discoverable via distribution-spec 1.1 `GET /referrers/<digest>`.

### Modified Capabilities
None (`pipeline/_step-spec.nix` enum is a private internal type, not a spec).

## Impact

- New pipeline category `provenance`; existing enum must accept the new value.
- New shared library callable from every future attestation/signing/SBOM step.
- Push step output shape gains a `NIX_OCI_PUSHED_DIGEST` marker; downstream parsers must tolerate this line.
- Registry compatibility: primary targets (GHCR, ECR, ACR, GAR, Docker Hub, zot, Harbor 2.8+) speak the referrers API; pre-3.47 Nexus and old Artifactory fall back to tag-schema, documented in the new architecture page.
- No user-visible option surface added; the step is opt-out via `oci.pipeline.steps.referrer-attach.enabled = false`.

## Context

See proposal.md - Why. Extra grounding for the design choices below:

- nix2container (pinned `nlewo/nix2container@76be960`) does not emit OCI image-spec 1.1 manifests: `nix/image.go` and `types/types.go:82` set only `MediaType` on layers; no `Subject`, `ArtifactType`, or v1.1 `SchemaVersion`.
- The pinned patched skopeo (`skopeo-nix2container`) writes Docker v2s2 / OCI 1.0 by default.
- `nix/modules/oci/security/signing/lib.nix` only calls `cosign sign`. There is no `cosign attest`, no in-toto Statement builder, no `oras attach`, and no code that resolves the pushed digest for downstream binding.
- `nix/modules/oci/pipeline/_step-spec.nix:32-45` declares `category` as a closed enum `policy | cve | lint | compliance | sbom | signing | structure | probe | license | push | credentials`. Adding a provenance step requires extending the enum.
- `nix/modules/oci/testing/_python-gen.nix:283-317` already reads referrers via `curl /v2/.../referrers/<digest>` in tests (SOCI zTOC discovery); the pattern exists for reads but not writes.

## Goals / Non-Goals

**Goals:**
- One shared library callable from every future attestation, signing, SBOM, VEX, or policy step: `mkAttachReferrer { imageRef, artifactType, mediaType, blob }`.
- Correct digest binding: the pushed image's sha256 is captured and passed as the `subject` of every attached referrer.
- Registry-compat matrix documented; primary registries work out of the box; pre-1.1 registries fall back with a clear diagnostic.
- Pipeline registry accepts a new `provenance` category so this and future provenance steps validate.

**Non-Goals:**
- Upstream nix2container patch to emit v1.1 manifests with `subject` field. Blocked on upstream review, 2+ week detour. Deferred; use `oras attach` post-hoc.
- A generic in-toto Statement wrapper. That is `cosign-attest-in-toto-wrapper` and depends on this substrate.
- Rewriting `mkPushAllTagsApp`'s 3x tag-copy optimisation. The digest capture is additive; the copy strategy is untouched.

## Decisions

### Post-hoc `oras attach` over an upstream nix2container patch

The workaround (`oras attach` after push) is a shell-level `oras attach --artifact-type <type> --distribution-spec v1.1 <image-ref> <blob>` invocation. It works whether the base image is OCI 1.0 or 1.1, needs no changes to nix2container, and is compatible with GHCR, ECR, ACR, GAR, Docker Hub, zot, and Harbor 2.8+. Alternative considered: fork nix2container's `nix/image.go` to populate `Subject`/`ArtifactType`/`SchemaVersion`. Rejected because (a) it also requires patching the `skopeo-nix2container` transport, (b) upstream review latency is unbounded, (c) our downstream users benefit immediately from `oras discover` without waiting.

### Digest capture on the push step, not the attach step

`nix/modules/oci/internal/packages/push.nix` and the turbo variant both emit `NIX_OCI_PUSHED_DIGEST=<sha256>` on stdout after every successful push. The attach step reads it via a small pipeline-level environment marker. Alternative: attach step re-resolves the digest via `skopeo inspect`. Rejected because (a) it doubles network calls to the registry, (b) it introduces a race window where the registry might return a stale digest if garbage collection is running.

### New pipeline `category` value: `provenance`

Extending the closed enum in `_step-spec.nix` is the smallest possible edit that unblocks this step and every future one (SLSA, VEX, SCAI). Alternative: reuse the existing `signing` category. Rejected because `signing` currently means "sign the image manifest itself" and conflating attach-a-referrer semantics with sign-the-manifest semantics would confuse the pipeline gate DAG.

### Pipeline phase: `post-push` (existing)

Referrer attach requires the image to be pushed (the referrer subject is a digest reference to something the registry has). `post-push` is the correct phase; no new phase needed.

### Fallback path for pre-1.1 registries

When the target registry does not implement the referrers API (detected by `oras discover` returning `404 UNSUPPORTED`), the step SHALL fall back to the tag-schema `<subject-digest>.<artifactType-hash>`. This preserves discoverability against pre-3.47 Nexus and older Artifactory without failing the pipeline. Documented; opt-out via `oci.container.provenance.referrerAttach.tagFallback = false`.

## Risks / Trade-offs

- **Registry drift risk** -> registry-compat matrix in `docs/content/architecture/supply-chain-attach.md`, verified quarterly against the primary targets.
- **Marker parsing brittleness** (stdout `NIX_OCI_PUSHED_DIGEST=` line) -> BDD test that grep-parses the marker and fails visibly if the format drifts; downstream steps use a single shared parser helper.
- **Additional CI wall-clock** (one `oras attach` per referrer) -> `oras attach` is a single HTTP PUT of a small blob plus a manifest update; typically sub-second. Documented.
- **Ambient credential requirement** (`oras` needs the registry credentials that `push` already used) -> the attach step inherits the same credential-provider path as `push`; assertion catches config drift.

## Migration Plan

1. Ship `oras` package, `mkAttachReferrer` lib, pipeline enum extension, and `NIX_OCI_PUSHED_DIGEST` marker in a single change. All backward-compatible.
2. Register `provenance/referrer-attach` step with opt-out disabled by default; consumers opt in as their upstream attestation stories land (SLSA, VEX, SCAI).
3. When nix2container upstream ships v1.1 emit natively, we deprecate the `oras attach` post-hoc path in favour of native emit. Documented as a future note; not scoped here.

## Open Questions

None material.

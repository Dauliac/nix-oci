## Context

See proposal.md - Why. Grounding:

- `flake.lock` is the ground-truth manifest of every input to a Nix build. Each entry has a lock source URL and a content hash (`narHash` or subresource-hash equivalent). SLSA `resolvedDependencies[]` expects `uri` and `digest.sha256`; the mapping is direct.
- SLSA v1.1 schema (`https://slsa.dev/provenance/v1`) requires `buildDefinition.buildType`, `buildDefinition.externalParameters`, `buildDefinition.resolvedDependencies`, `runDetails.builder.id`, `runDetails.metadata`.
- `runDetails.builder.id` must be a stable identity that a verifier can pin: a GitHub Actions OIDC issuer, a hydra instance URL, a keyless cosign identity, or a self-hosted CA-signed identity.
- Local developer builds have no stable builder identity. SLSA emit for those is meaningless.

## Goals / Non-Goals

**Goals:**
- Emit a SLSA v1.1 predicate that is byte-stable for identical `flake.lock` + flake ref + builder identity, so `slsa-verifier` can pin against it.
- Reach SLSA L1 by construction (all inputs in `flake.lock`, reproducible build).
- Reach SLSA L2 in CI (builder identity signed by keyless cosign, provenance signed by CI identity).

**Non-Goals:**
- SLSA L3 automation. L3 requires isolated key material and hardened build environment; documented as a checklist, not enforced.
- Multi-image or aggregate attestations. Each image gets its own SLSA statement bound to its digest.
- Non-Nix input tracking (system packages, host toolchain). Only `flake.lock`-declared inputs are enumerated.

## Decisions

### `buildType = "https://github.com/nlewo/nix2container/build/v1"` (project-owned URI)

SLSA `buildType` is a project-chosen URI identifying the build recipe shape. We mint one under the project's authoritative URL so verifiers can pin against a specific recipe version. Alternative: use `https://slsa.dev/nix-flake/v1` if one materialises. Not standardised as of 2026; we watch upstream.

### `externalParameters` shape

- `flakeRef`: the flake reference the build was invoked against (e.g., `github:owner/repo/rev`).
- `subflakePath`: the path within the flake to the container attribute (e.g., `packages.x86_64-linux.myImage`).
- `args`: any pass-through arguments (empty by default).

Alternative considered: include the full flake evaluation state. Rejected because it is too large for a predicate and non-deterministic across nix versions.

### `resolvedDependencies` derived per lock entry

For each entry in `flake.lock.nodes.<name>.locked`:
- `uri` = `type://original.owner/repo/rev` for github, mirrored equivalents for other input types.
- `digest.sha256` = the input's content hash from `narHash` (base64-encoded sha256 unpacked to hex).
- `name` = the node's name (e.g., `nixpkgs`).

Alternative: use `narHash` verbatim. Rejected because SLSA expects hex sha256; verifier tooling assumes that shape.

### `builder.id` sourcing

Priority order:
1. Explicit `oci.container.provenance.slsa.builderId` (highest precedence).
2. `oci.pipeline.builder.id` (project-level default).
3. Assertion failure with actionable message.

Rationale: local developer builds must not silently emit meaningless SLSA. Alternative: derive from hostname. Rejected because hostnames are not verifier-pinnable identities.

### Attach via `mkAttestation` from `cosign-attest-in-toto-wrapper`

The predicate is handed to `mkAttestation` with `predicateType = "https://slsa.dev/provenance/v1"`. No custom signing path in this change.

## Risks / Trade-offs

- **Predicate byte-stability across nix versions** -> `builtins.toJSON` output order depends on attrset key sort, which is stable in nix. We pin key order explicitly by constructing the attrset with a deterministic keys sequence.
- **Timestamp fields** (`buildStartedOn`, `buildFinishedOn`) are inherently non-reproducible -> we set them from `SOURCE_DATE_EPOCH` when available (Nix build hook), else from `runDetails.metadata.invocationId`.
- **flake.lock schema drift** across Nix versions -> we parse via `builtins.fromJSON` and tolerate additional fields; if the top-level shape ever changes materially, we update the generator.

## Migration Plan

1. Depends on `cosign-attest-in-toto-wrapper` and `oci-attach-referrer-substrate` landing first.
2. Ship with `enabled = false` default so no configuration is silently disturbed.
3. Consumers opt in when their builder identity is configured (documented one-line CI snippet for GitHub Actions).
4. Add a `slsa-verifier`-based BDD test to prove verifiability.

## Open Questions

None material.

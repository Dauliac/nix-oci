## Why

For projects that publish nix-oci images from GitHub Actions, GitHub's `actions/attest-build-provenance` action is a zero-config second-signer: it binds an artifact digest to a SLSA v1.0 predicate, signs it with a short-lived Sigstore certificate keyed to the workflow identity, and stores the bundle in GitHub's own tuf-backed transparency log. Any consumer with `gh` 2.60+ (pinned `gh 2.83.2` clears this) can verify the attestation with a single command against no additional infrastructure. This complements user-owned cosign signatures (which prove "I signed this") with a builder-owned signature (which proves "GitHub ran the workflow that produced this").

## What Changes

- Add `.github/workflows/attest-images.yml` (or extend an existing publish workflow) with:
  - `permissions: id-token: write, attestations: write, contents: read`
  - a step that, after `nix run .#push`, invokes `actions/attest-build-provenance@v3` with the built image `subject-digest` and `push-to-registry: true`
- Add a documentary per-container option file `nix/modules/oci/_oci/signing/attestations/github-enabled.nix` (bool, default false). This does not gate CI execution but signals project intent and enables a doc-link generator.
- Extend `nix/modules/oci/lib/mkPushAllTagsApp.nix` to emit `NIX_OCI_PUSHED_DIGEST=<sha256>` on stdout (shared with `oci-attach-referrer-substrate`; if that has landed, this is a no-op reference).
- Docs: new `docs/content/how-to/github-attestations.md` walking through the CI setup, the required workflow permissions, and `gh attestation verify --repo <owner>/<repo> <image-ref>` on the consumer side.
- Optional: a validation script (Nix expression, not a workflow) that asserts the workflow file has the required `permissions:` block; run in a pure check under `.#checks`.

## Capabilities

### New Capabilities
- `supply-chain/github-attestations`: GitHub Actions-native SLSA provenance attestation, keyed to the workflow identity, verifiable with `gh attestation verify` and independent of user-owned cosign keys.

### Modified Capabilities
None.

## Impact

- Only relevant when the project publishes from GitHub Actions; a no-op otherwise. Doc explicitly says so.
- Adds one workflow step and one permissions block; does not alter build-time behavior of any Nix derivation.
- Compatible with (and complementary to) `slsa-provenance-predicate`: the two provenance attestations coexist as separate referrers.
- Independent of `oci-attach-referrer-substrate` from a build-time perspective, but shares the `NIX_OCI_PUSHED_DIGEST` marker with it; keeps a single source of truth.

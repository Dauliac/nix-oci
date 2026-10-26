## 1. Packaging

- [x] 1.1 Add `nix/modules/oci/packages/oras.nix` pinning `pkgs.oras`; verify `nix build .#oras` succeeds and `oras version` reports the expected version
- [x] 1.2 Extend `flake.nix` or the packages aggregator to export `oras` under `oci.packages`; verify with `nix eval .#packages.<system>.oras.name`

## 2. Enum extension

- [x] 2.1 Extend the `category` enum in `nix/modules/oci/pipeline/_step-spec.nix` with `"provenance"`; verify existing steps still validate via `nix eval .#checks.<system>.pipeline-spec-eval`
- [x] 2.2 Add a `post-push` phase value if absent from `phase` enum; verify enum accepts it (no-op: already present)

## 3. Digest capture

- [x] 3.1 Modify `nix/modules/oci/internal/packages/push.nix` to emit `NIX_OCI_PUSHED_DIGEST=sha256:<hex>` on stdout after successful push; verify by running the push script against a local zot and grepping stdout (edit landed in the underlying `nix/modules/oci/lib/mkPushApp.nix` and `nix/modules/oci/lib/mkPushAllTagsApp.nix`, which are what `internal/packages/push.nix` wires into flake apps; 45 checks re-evaluate)
- [x] 3.2 Mirror the change in the turbo push variant under `nix/modules/oci/internal/packages/`; verify with the same integration test (scope widened per spec req 2 "any backend": applied to `nix/modules/oci/multi-arch/lib.nix` merge step and `nix/modules/oci/multi-arch/crossBuildLib.nix` final push in addition to the turbo-handling `mkPushAllTagsApp.nix`)

## 4. Attach substrate

- [ ] 4.1 Create `nix/modules/oci/lib/mkAttachReferrer.nix` exporting `mkAttachReferrer { imageRef, artifactType, mediaType, blob }` that invokes `oras attach --artifact-type <type> <ref> <blob>` and emits `NIX_OCI_REFERRER=sha256:<hex>` on stdout; verify with a synthetic invocation script that attaches a fake JSON blob and checks the marker
- [ ] 4.2 Add tag-schema fallback path when `oras attach` returns UNSUPPORTED; verify against a mock pre-1.1 registry (`registry:2.7`) that the fallback tag is created

## 5. Pipeline step registration

- [ ] 5.1 Register `provenance/referrer-attach` in `nix/modules/oci/pipeline/step-registrations.nix` (phase `post-push`, category `provenance`, deps `[ "push" ]`); verify with `openspec status` and pipeline-eval check
- [ ] 5.2 Add per-container option file `nix/modules/oci/_oci/provenance/referrer-attach/{enabled,tag-fallback}.nix`; verify option surface via `nix eval`

## 6. BDD test coverage

- [ ] 6.1 Add `nix/modules/oci/containers/_tests/provenance/referrer-attach.test.nix` with scenarios: attach succeeds, referrer discoverable via `oras discover`, `GET /v2/<name>/referrers/<digest>` returns the manifest; verify test passes in VM harness against local zot
- [ ] 6.2 Extend the BDD to cover the tag-schema fallback against a `registry:2.7` fixture; verify fallback path exits zero and tag exists

## 7. Documentation

- [ ] 7.1 Write `docs/content/architecture/supply-chain-attach.md` covering the substrate, the `oras attach` post-hoc trade-off, and a registry-compat matrix; verify by rendering the docs site locally and cross-linking from `docs/content/architecture/index.md`

# Tasks, fix-documentation-drift

## 1. Pipeline-refactor stragglers

- [x] **1.1** [critical C1] `docs/content/getting-started.md:54-59`, replace `nix run .#oci-hello.copyToPodman` / `.copyToDockerDaemon` with `nix run .#oci-load-podman-hello` / `oci-load-docker-hello`. Ground truth: `nix/modules/oci/outputs/enable-load-podman.nix:6`, `enable-load-docker.nix:6`. (PR #16)
- [x] **1.2** [critical C2] `docs/content/getting-started.md:285-291`, Step 11 currently claims `oci-cve-trivy-*` / `oci-lint-dockle-*` / `oci-policy-conftest-*` apps exist. They don't (`nix/modules/oci/outputs/apps.nix:3-7`). Rewrite the step to describe: (a) scanners run at `nix build .#oci-<name>`, (b) reports land under `NIX_OCI_REPORT_DIR`, (c) point at `nix/modules/oci/pipeline/step-registrations.nix` for the full step registry. (PR #16)
- [x] **1.3** [major M3] `docs/content/how-to/container-modules-api.md:60-66`, always nest `cve.trivy.enabled` under `oci.containers.<name>`. Add a one-line callout that `oci.perContainer` sets shared defaults across containers. (PR #16)
- [ ] **1.4** [major M9] Follow-up decision: expose per-tool scanning apps in `oci.pipeline` (for example `oci-cve-trivy-<name>`), or accept that scanners run only under `nix build` + gate. Owner: TBD. `blocking:human`.
- [x] **1.5** Grep sweep: `git grep -nE 'oci-cve|oci-lint|oci-policy|copyToPodman|copyToDockerDaemon|CIMERA_' -- docs/ examples/ tests/ flake.nix nix/`, record any remaining stale usages before closing this section. Stragglers fixed: `nixos-containers.md`, `policy-integrity-testing.md`, `container-metadata-wiring.md` (diagram), `container-probes.md`.

## 2. Wrong source-tree paths

- [x] **2.1** [critical C3] `docs/content/architecture/automatic-metadata.md:34`, `_nixos/oci/service-adapters/` to `nix/modules/_nixos-oci/service-adapters/`. (PR #16)
- [x] **2.2** [critical C6] `docs/content/test-reference/nix-lib-testing.md:35` and `testing-flake-parts-options.md:48`, replace every `nix/modules/oci/_testing/` with `nix/modules/oci/testing/`. (PR #16)

## 3. `readOnly` computed options in examples

- [x] **3.1** [critical C5] `docs/content/how-to/container-modules-api.md:144-146`, drop `multiArch.enabled = true`; only set `systems`. (PR #16)
- [x] **3.2** [major M4] `docs/content/how-to/share-containers-across-modules.md:143-144`, same fix. (PR #16)
- [x] **3.3** Audit sweep: `git grep -nE 'multiArch\.enabled\s*=\s*true' -- docs/`, empty.

## 4. `test.containerStructureTest` interface

- [x] **4.1** [critical C4] `docs/content/how-to/container-modules-api.md:133-136`, resolved via option (a): `configs` and `coherence` declared as real `mkOption`s under `nix/modules/oci/_oci/test/containerStructureTest/`. (PR #16)

## 5. Broken cross-references

- [x] **5.1** [major M1] `docs/content/architecture/index.md:14-40`, `security-defaults` redirected to existing page; the four other "planned" pages replaced with inline descriptions pointing at option reference. (PR #16)
- [x] **5.2** `docs/content/architecture/design-choices.md:16-22`, same pick-list applied. (PR #16)
- [x] **5.3** `docs/content/architecture/archive-less-container-building.md:431`, resolved. (PR #16)
- [x] **5.4** `docs/content/architecture/automatic-labeling.md:250`, resolved to existing `security-defaults.html`. (PR #16)
- [x] **5.5** No stubs chosen; pages either exist or are described inline, so no follow-up bead needed. If dedicated pages are wanted later, file at that time.

## 6. Test-reference rewrite

- [x] **6.1** [critical C7] `docs/content/test-reference/testing-flake-parts-options.md:9-11`, rewritten to enumerate the actual `testing.*` options. (PR #16)
- [x] **6.2** [major M5] Rewrote "no `testing.enable` flag" line. (PR #16)
- [x] **6.3** [minor] Added `assertions.succeeds` / `assertions.imageConfig` to example spec. (PR #16)

## 7. Reference-build resilience

- [ ] **7.1** `nix/docs.nix:135-174`, replace the inline duplicated `oci.enable` / `oci.backend` / `oci.containers` schema with `import`s of `nix/modules/deploy/nix-oci/options/{enable,backend,containers}.nix`, evaluated through the same `nixosOptionsDoc` pipeline. `blocking:human`.
- [ ] **7.2** Verify: `nix build .#legacyPackages.<system>.docs` succeeds; rendered `reference/*.md` byte-diff (modulo `/nix/store/…` hashes) matches pre-change output. Depends on 7.1.

## 8. Minor cleanup

- [x] **8.1** [minor] `docs/content/security/container-probes.md:8`, intro already says "four security probes"; probes table has four rows. (PR #16)
- [x] **8.2** [minor] `docs/content/getting-started.md:213-217`, `performance.compression` example mentions `"gzip"`, `"zstd"`, and `"gzip:estargz"`. (PR #16)
- [x] **8.3** [minor] `docs/content/getting-started.md:54`, annotated `nix build .#oci-hello` output (`result/bin/{load-podman,load-docker,push,sandbox}`).
- [x] **8.4** [minor] `docs/content/architecture/container-metadata-wiring.md:87-90,587-590,637-639,683-684,748-749`, standardized half-paths to absolute-from-repo-root.
- [x] **8.5** [minor] `docs/content/architecture/oci-standards-compliance.md:55-67`, added code citation for the `perms` mechanism (`nix-support.nix` block). (PR #16)
- [ ] **8.6** [minor] `docs/content/architecture/performance.md:295`, verify NixOS Wiki: Build flags URL still resolves; update if stale. (needs network probe)
- [x] **8.7** [minor] `docs/content/reference/*.md`, added a header note (once per file) that the page is autogenerated at build; points at `nix build .#legacyPackages.<system>.docs`.

## 9. Getting-started style consistency

- [x] **9.1** [major M2] `docs/content/getting-started.md:34,77,239`, normalized import path style to destructured `nix-oci.modules.{flake,nixos}.nix-oci` matching `templates/default/flake.nix`.

## 10. Deploy how-to parity

- [x] **10.1** [major M7] `docs/content/how-to/deploy-modules.md`, added per-container CVE-scanning example section with `cve.trivy.enabled = true`, sbom, lint, policy in a NixOS deploy module.

## Verification (after all sections)

- [x] **V1** `git grep -nE '_testing/|_nixos/oci|copyToPodman|copyToDockerDaemon|CIMERA_' -- docs/` returns empty.
- [x] **V2** `git grep -nE 'multiArch\.enabled\s*=\s*true' -- docs/` returns empty.
- [ ] **V3** For each internal Markdown link under `docs/content/`, verify the target file exists (script: `awk '/\]\(\.\.?\//' + test -f`).
- [ ] **V4** `nix build .#legacyPackages.<system>.docs` succeeds. Deferred with 7.1.
- [ ] **V5** A reviewer new to nix-oci walks `getting-started.md` end-to-end on a clean checkout and reports every friction point. `blocking:human`.

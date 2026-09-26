# Tasks  -  fix-documentation-drift

## 1. Pipeline-refactor stragglers

- [ ] **1.1** [critical C1] `docs/content/getting-started.md:54-59`  -  replace `nix run .#oci-hello.copyToPodman` / `.copyToDockerDaemon` with `nix run .#oci-load-podman-hello` / `oci-load-docker-hello`. Ground truth: `nix/modules/oci/outputs/enable-load-podman.nix:6`, `enable-load-docker.nix:6`.
- [ ] **1.2** [critical C2] `docs/content/getting-started.md:285-291`  -  Step 11 currently claims `oci-cve-trivy-*` / `oci-lint-dockle-*` / `oci-policy-conftest-*` apps exist. They don't (`nix/modules/oci/outputs/apps.nix:3-7`). Rewrite the step to describe: (a) scanners run at `nix build .#oci-<name>`, (b) reports land under `NIX_OCI_REPORT_DIR`, (c) point at `nix/modules/oci/pipeline/step-registrations.nix` for the full step registry.
- [ ] **1.3** [major M3] `docs/content/how-to/container-modules-api.md:60-66`  -  always nest `cve.trivy.enabled` under `oci.containers.<name>`. Add a one-line callout that `oci.perContainer` sets shared defaults across containers.
- [ ] **1.4** [major M9] Follow-up decision: expose per-tool scanning apps in `oci.pipeline` (e.g. `oci-cve-trivy-<name>`), or accept that scanners run only under `nix build` + gate. Owner: TBD. `blocking:human`.
- [ ] **1.5** Grep sweep: `git grep -nE 'oci-cve|oci-lint|oci-policy|copyToPodman|copyToDockerDaemon|CIMERA_' -- docs/ examples/ tests/ flake.nix nix/`  -  record any remaining stale usages before closing this section.

## 2. Wrong source-tree paths

- [ ] **2.1** [critical C3] `docs/content/architecture/automatic-metadata.md:34`  -  `_nixos/oci/service-adapters/` → `nix/modules/_nixos-oci/service-adapters/`.
- [ ] **2.2** [critical C6] `docs/content/test-reference/nix-lib-testing.md:35` and `testing-flake-parts-options.md:48`  -  replace every `nix/modules/oci/_testing/` with `nix/modules/oci/testing/`. Verify with `grep -n _testing docs/content/test-reference/`.

## 3. `readOnly` computed options in examples

- [ ] **3.1** [critical C5] `docs/content/how-to/container-modules-api.md:144-146`  -  drop `multiArch.enabled = true`; only set `systems`.
- [ ] **3.2** [major M4] `docs/content/how-to/share-containers-across-modules.md:143-144`  -  same fix.
- [ ] **3.3** Audit sweep: `git grep -nE '\b(multiArch|[a-zA-Z_]+)\.enabled\s*=' -- 'docs/**/*.md'`  -  for each hit, verify the option is not `readOnly` in code.

## 4. `test.containerStructureTest` interface

- [ ] **4.1** [critical C4] `docs/content/how-to/container-modules-api.md:133-136`  -  currently claims `test.containerStructureTest.configs` and `.coherence` are settable; code only defines `.enabled`. Pick one:
  - (a) Declare `configs` and `coherence` as real `mkOption`s under `nix/modules/oci/_oci/test/containerStructureTest/`.
  - (b) Rewrite the doc to describe the current single-option interface + auto-generated coherence.
  - Recommend (b) for this change; (a) as a follow-up. `blocking:human`.

## 5. Broken cross-references

- [ ] **5.1** [major M1] `docs/content/architecture/index.md:14-40`  -  for each of the five referenced-but-missing pages (`security-defaults`, `multi-arch-images`, `nixos-home-manager-integration`, `sandbox`, `optimize-layers`), pick: (a) redirect to an existing page, (b) inline the description, (c) stub with a "planned" note. `blocking:human` for the picks.
- [ ] **5.2** `docs/content/architecture/design-choices.md:16-22`  -  same set of five links; apply the same pick-list from 5.1.
- [ ] **5.3** `docs/content/architecture/archive-less-container-building.md:431`  -  resolve `optimize-layers.md` link consistently with 5.1.
- [ ] **5.4** `docs/content/architecture/automatic-labeling.md:250`  -  resolve `security-defaults.md` link consistently with 5.1.
- [ ] **5.5** File a follow-up bead for whichever pages we choose to stub: content-writing is out of scope here.

## 6. Test-reference rewrite

- [ ] **6.1** [critical C7] `docs/content/test-reference/testing-flake-parts-options.md:9-11`  -  rewrite the "no user-facing options" paragraph to enumerate the `testing.*` options actually defined under `nix/modules/deploy/nix-oci/nixos/_test/` (`testing.enable`, `testing.registry.{enable,port}`, `testing.extraPackages`, `testing.cosign.localKeys`, `testing.db.{trivy,grype}.path`, `testing.turbo.forceEnable`, `testing.appScripts`).
- [ ] **6.2** [major M5] Same file, same paragraph  -  rewrite "no `testing.enable` flag" to "importing the test module auto-enables it; `testing.enable = false` opts out".
- [ ] **6.3** [minor] Add `assertions.succeeds` (or `assertions.imageConfig`) to the example spec at lines 34-43  -  reference actual usage in `nix/modules/oci/containers/_tests/labels.test.nix:32-35` or `entrypoint.test.nix:51-56`.

## 7. Reference-build resilience

- [ ] **7.1** `nix/docs.nix:135-174`  -  replace the inline duplicated `oci.enable` / `oci.backend` / `oci.containers` schema with `import`s of `nix/modules/deploy/nix-oci/options/{enable,backend,containers}.nix`, evaluated through the same `nixosOptionsDoc` pipeline.
- [ ] **7.2** Verify: `nix build .#legacyPackages.<system>.docs` succeeds; rendered `reference/*.md` byte-diff (modulo `/nix/store/…` hashes) matches pre-change output.

## 8. Minor cleanup

- [ ] **8.1** [minor] `docs/content/security/container-probes.md:8`  -  either add a `dgoss` row to the probes table or change "five" → "four" in the intro.
- [ ] **8.2** [minor] `docs/content/getting-started.md:213-217`  -  extend `performance.compression` example to mention `"gzip"` and `"gzip:estargz"` alongside `"zstd"`. Ground truth: `nix/modules/oci/containers/_options/performance/compression.nix:16-20`.
- [ ] **8.3** [minor] `docs/content/getting-started.md:54`  -  annotate what `nix build .#oci-hello` produces (`result/bin/{load-podman,load-docker,push,sandbox}`).
- [ ] **8.4** [minor] `docs/content/architecture/container-metadata-wiring.md:87-90,587-590,637-639,683-684,748-749`  -  standardize half-paths to absolute-from-repo-root (`nix/modules/oci/containers/_options/…`).
- [ ] **8.5** [minor] `docs/content/architecture/oci-standards-compliance.md:55-67`  -  add code citations (`nix/modules/oci/lib/mkOCIImage.nix`) for the `perms` mechanism; same for compression at line 30.
- [ ] **8.6** [minor] `docs/content/architecture/performance.md:295`  -  verify NixOS Wiki: Build flags URL still resolves; update if stale.
- [ ] **8.7** [minor] `docs/content/reference/*.md`  -  add a header note (once) that the file is auto-generated at build; point at `nix build .#legacyPackages.<system>.docs` for local rendering.

## 9. Getting-started style consistency

- [ ] **9.1** [major M2] `docs/content/getting-started.md:34,77`  -  normalize import path style to match `templates/default/flake.nix:18` (bare `nix-oci.modules.flake.nix-oci`, not `inputs.nix-oci.modules.flake.nix-oci`). Apply consistently across all steps.

## 10. Deploy how-to parity

- [ ] **10.1** [major M7] `docs/content/how-to/deploy-modules.md`  -  add a per-container CVE-scanning example mirroring the flake-parts guide, showing `oci.containers.<name> = { cve.trivy.enabled = true; ... }` in a NixOS module.

## Verification (after all sections)

- [ ] **V1** `git grep -nE '_testing/|_nixos/oci|copyToPodman|copyToDockerDaemon|CIMERA_' -- docs/` returns empty.
- [ ] **V2** `git grep -nE 'multiArch\.enabled\s*=\s*true' -- docs/` returns empty.
- [ ] **V3** For each internal Markdown link under `docs/content/`, verify the target file exists (script: `awk '/\]\(\.\.?\//' + test -f`).
- [ ] **V4** `nix build .#legacyPackages.<system>.docs` succeeds.
- [ ] **V5** A reviewer new to nix-oci walks `getting-started.md` end-to-end on a clean checkout and reports every friction point.

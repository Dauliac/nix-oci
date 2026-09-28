# Dendritic Pattern Audit

**Date**: 2026-09-26
**Scope**: Compare the `nix-oci` flake structure against the canonical Dendritic Pattern as defined by [mightyiam/dendritic](https://github.com/mightyiam/dendritic) and the [denful](https://denful.dev/) ecosystem (`import-tree`, `flake-file`, `dendrix`, ...).
**Method**: Read the primary sources ([`denful.dev`](https://denful.dev/), [`denful.dev/ecosystem/overview`](https://denful.dev/ecosystem/overview/), [`mightyiam/dendritic README`](https://github.com/mightyiam/dendritic), [`denful/import-tree README`](https://github.com/denful/import-tree), [`import-tree.oeiuwq.com` docs](https://import-tree.denful.dev)), quote the rules, then cross-check against the local repo file-by-file.

---

## 1. Summary

The repo is **near state-of-the-art on the core Dendritic axioms** (one feature per file, path names the feature, `flake-parts` as top-level, `import-tree` for auto-discovery, `_`-prefix for private helpers, `deferredModule`-backed storage of lower-level modules via `flake.modules.{nixos,homeManager,systemManager}.*`, and the "declare your own options" discipline the canon calls out as an anti-pattern to skip). It goes beyond the canon by pushing the pattern to **one option per file** and layering a filename-suffix router (`*.lib.nix` / `*.test.nix` / plain `*.nix`) that the ecosystem does not (yet) formalize.

The biggest gaps are (a) **no adoption of adjacent denful tools** (`flake-file` for typed inputs, `checkmate` for zero-dep formatter+unit-tests, `fastest` for parallel `nix-unit`) even where they would directly replace hand-rolled infrastructure, and (b) a `nix2container` input threaded through `specialArgs` on the deploy submodule, which the canon lists as an anti-pattern ([`specialArgs` pass-thru](https://github.com/mightyiam/dendritic#specialargs-pass-thru)) though in this case it is a documented tradeoff for the shared-eval NixOS submodule and probably worth keeping. A minor internal DRY concern: three recursive `readDir` walkers (`nix/lib/discoverModules.nix`, `_test/default.nix`, `_snapshotter/default.nix`) reimplement the same "walk, skip `_`, filter by suffix" algorithm and could collapse into one shared helper. None of them are duplicating `import-tree`, which by design refuses to look inside `_`-prefixed subtrees (see section 5).

Biggest strength: **the option tree literally is the module tree** (`_options/hardening/seccomp.nix` -> `options.hardening.seccomp`) and BDD test specs live next to it (`_tests/hardening/seccomp.test.nix`), routed by filename suffix through a single `discoverModules` helper. That's a more disciplined interpretation of "path names the feature" than the canonical examples show.

---

## 2. Dendritic canon (as of 2026-09-26)

Every rule below is a verbatim quote from a primary source; the source URL follows each quote.

### 2.1 Core pattern rules ([`mightyiam/dendritic`](https://github.com/mightyiam/dendritic))

- **Top-level configuration**: "The top-level configuration facilitates the declaration and evaluation of lower-level configurations, such as NixOS, home-manager and nix-darwin. Commonly, this top-level configuration is a flake-parts configuration, but it does not have to be." [source](https://github.com/mightyiam/dendritic#top-level-and-lower-level-modules-and-configurations)
- **Every file is a top-level module**: "In the dendritic pattern every Nix file except for entry points such as `default.nix` and `flake.nix` is a module of the top-level configuration." [source](https://github.com/mightyiam/dendritic#top-level-and-lower-level-modules-and-configurations)
- **One feature, one path**: "every top-level module: implements a single feature ... across all configurations that that feature applies to ... is at a path that serves to name that feature." [source](https://github.com/mightyiam/dendritic#top-level-and-lower-level-modules-and-configurations)
- **Lower-level modules as option values**: "Lower-level modules and configurations such as NixOS, home-manager and nix-darwin are stored as option values in the top-level configuration." [source](https://github.com/mightyiam/dendritic#top-level-and-lower-level-modules-and-configurations)
- **Merge via `deferredModule`**: "The Nixpkgs module system type `deferredModule` and similar implementations feature *value merging*. This allows multiple lower-level module values to merge under one distinct name." [source](https://github.com/mightyiam/dendritic#lower-level-module-merging)
- **Automatic importing**: "Since all non-entry-point files are top-level modules and their paths convey meaning only to the author, they can all be automatically imported using a trivial expression or [a small library](https://github.com/vic/import-tree)." [source](https://github.com/mightyiam/dendritic#automatic-importing)
- **File-path independence**: "Each file can be freely renamed and moved, and it can be split when it grows too large or too complex." [source](https://github.com/mightyiam/dendritic#file-path-independence)

### 2.2 Canonical anti-patterns ([`mightyiam/dendritic#anti-patterns`](https://github.com/mightyiam/dendritic#anti-patterns))

- **Not declaring options**: "Using *only* existing options (such as flake-parts' `flake.modules`) for the storage of lower-lever modules prevents us from translating our mental model of the system into code. Declaring options for the storage of modules is easy." [source](https://github.com/mightyiam/dendritic#not-declaring-options)
- **`specialArgs` pass-thru**: "In the dendritic pattern every file is a top-level module and can therefore add values to the top-level `config`. In turn, every file can also read from the top-level `config`. This makes the sharing of values between files seem trivial in comparison." (i.e. do not thread values via `specialArgs`) [source](https://github.com/mightyiam/dendritic#specialargs-pass-thru)
- **Lower-level module name proliferation**: "One may be tempted to assign each lower-level module to its own unique name. Such granularity would result in a great number of named modules. The cost of such a pattern is that `imports` lists would end up being much longer than necessary. ... Consider merging multiple non-distinct lower-level modules under one distinct name." [source](https://github.com/mightyiam/dendritic#lower-level-module-name-proliferation)
- **Fanaticism (exceptions are fine)**: "The dendritic pattern is merely a pattern. It's not a religion, law or a mandate. ... Having Nixpkgs `callPackage` files interspersed among top-level module files is one reasonable exception ... they'd have to be excluded from automatic importing. A suggested naming scheme for these: `my-package.pkg.nix`." [source](https://github.com/mightyiam/dendritic#fanaticism)
- **`enable` options**: "Often created using `lib.mkEnableOption`, `enable` options are necessary when a module is imported even though a feature it provides should not necessarily be enabled. This anti-pattern originates in NixOS ... In most cases, importing a module should enable the feature that it provides." [source](https://github.com/mightyiam/dendritic#enable-options)

### 2.3 `import-tree` conventions ([`denful/import-tree README`](https://github.com/denful/import-tree), [`import-tree docs`](https://import-tree.denful.dev))

- **Default filter**: "By default, paths having `/_` are ignored." [source](https://github.com/denful/import-tree#quick-start)
- **Filter defaults spelled out**: "By default, `import-tree` includes files that: 1. Have the `.nix` suffix 2. Do not have `/_` in their path (underscore-prefixed directories are ignored)." [source](https://import-tree.denful.dev/guides/filtering/)
- **Chainable API**: "Chain `.filter`, `.match`, `.map`, `.addPath`, and more to customize discovery." [source](https://import-tree.denful.dev/reference/api/)
- **Extensibility**: "Extensible: `.addAPI` to create domain-specific instances." [source](https://github.com/denful/import-tree#features)
- **`initFilter` replaces the default**: "`initFilter` replaces the built-in `.nix` + no-`/_` filter entirely. Use it to discover non-Nix files or change the ignore convention." [source](https://import-tree.denful.dev/guides/filtering/)
- **Canonical flake-parts wiring**: `flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules)` [source](https://github.com/denful/import-tree#dendritic-flake-parts)
- **`/_` semantics**: "Use underscore-prefixed directories for helper code that shouldn't be auto-imported." [source](https://import-tree.denful.dev/guides/dendritic/)

### 2.4 Denful ecosystem principles ([`denful.dev/ecosystem/overview`](https://denful.dev/ecosystem/overview/))

- **Composable / no lock-in / minimal deps / well-tested / documented**: "small focused functions that combine naturally", "works with flakes, without flakes, with flake-parts, or standalone", "most libraries have zero or near zero external dependencies", "CI with checkmate, real test suites, real world validation", "each library has its own documentation site". [source](https://denful.dev/ecosystem/overview/)
- **Adjacent tools worth naming**: `flake-file` ("Define flake inputs as typed Nix module options"), `checkmate` ("Bundles treefmt and nix-unit"), `fastest` ("Parallel nix-unit compatible test execution"), `dendrix` ("Community-driven index of Aspect oriented aspects, layers, import-trees, and templates"), `dag` ("Home Manager's directed-acyclic-graph ordering helpers as standalone library"). [source](https://denful.dev/ecosystem/overview/)

### 2.5 flake-parts endorsement

- "Split your `flake.nix` into focused units, each in their own file." [source](https://flake.parts/)

---

## 3. Repo scorecard

Legend: `PASS` = fully aligned, `WARN` = partial or with caveats, `FAIL` = clear divergence.

| # | Canon rule | Verdict | Evidence |
|---|---|---|---|
| 1 | Top-level config is flake-parts | PASS | `flake.nix:30` calls `flake-parts.lib.mkFlake`; `flakeModules.modules` imported for typed `flake.modules.*` API (`flake.nix:36`). |
| 2 | Every file is a top-level module | PASS | 425 `.nix` files under `nix/modules/` are all flake-parts modules; entry points (`flake.nix`, `nix/module.nix`, per-partition `default.nix`) are the documented exceptions. Confirmed by sampling `nix/modules/flake/apps.nix`, `.../checks.nix`, `.../packages.nix`, `.../oci/lib/mkOCI.nix` (all set `config.perSystem.*`, i.e. real modules). |
| 3 | One feature per file, path names the feature | PASS+ | The repo goes further: **one *option* per file** (e.g. `oci/_oci/cve/grype/enabled.nix` -> `options.cve.grype.enabled`, `oci/containers/_options/hardening/enable.nix` -> `options.hardening.enable`). File path literally mirrors option path. Documented in project `MEMORY.md`. |
| 4 | Lower-level modules stored as top-level option values | PASS | Deploy modules registered under `flake.modules.nixos.*`, `flake.modules.homeManager.*`, `flake.modules.systemManager.*` (see `nix/modules/deploy/nix-oci/options/{enable,backend,containers}.nix`, `.../nixos/{load,run}-services.nix`, `.../home-manager/{load,run}-services.nix`, `soci-snapshotter/deploy/nixos.nix`). This is the `deferredModule` storage the canon calls "the pattern". |
| 5 | Merge via `deferredModule` | PASS | `nix/modules/deploy/nix-oci/options/containers.nix:48` declares `oci.perContainer = types.listOf types.deferredModule`. `nix/modules/oci/containers/perContainer.nix:35-65` implements a `deferredModuleWith { staticModules = ...}` type that value-merges option contributions across files. Same pattern reused in `perTag.nix` and `multiArch/perArch.nix`. |
| 6 | Automatic importing via `import-tree` | PASS | `flake.nix:15` inputs `import-tree`; `nix/module.nix:10` and `nix/flake-module.nix:16` both call `inputs.import-tree ./modules/deploy` / `./modules`. Canonical wiring per [import-tree README](https://github.com/denful/import-tree#dendritic-flake-parts). |
| 7 | `/_` = private, excluded from auto-import | PASS | 12 `_`-prefixed dirs: `_containers`, `_performance`, `_snapshotter`, `_test`, `_options`, `_tests`, `_archOptions`, `_oci`, `_testing`, `_home-manager-oci`, `_nixos-oci`. Each is either loaded selectively (via `discoverModules`) or as a submodule imports list. Confirmed via `find nix/ -type d -name "_*"`. |
| 8 | Filter methods (`.filter`, `.filterNot`, `.match`, `.map`, `.addPath`, `.addAPI`) used where needed | PASS (partial) | `nix/examples.nix:28` uses `inputs.import-tree.filterNot (path: lib.any (...) excludes)` idiomatically. `.map`, `.addAPI`, `.addScoped`, `.leaves`, `.files`, `.pipeTo` are **not** used; the repo instead has its own `discoverModules` for option-declaration-time discovery (see gap G1). |
| 9 | File-path independence (can rename freely) | WARN | Container-option files hardcode option paths that match the file path (`options.hardening.enable`), so a rename would require an option-path rename too. That's consistent with the *stronger* one-option-per-file convention the repo adopted, but it does trade away some of the "freely rename" flexibility the canon promises. |
| 10 | Anti-pattern: not declaring options | PASS | The canon warns against relying only on `flake.modules`. The repo declares dozens of typed options: `oci.perContainer`, `oci.containers`, `oci.pipeline.*`, `oci.testing.*`, plus per-container option trees under `_options/` and `_oci/`. `MEMORY.md` calls out `namespace.nix` (mounts `_oci/` as `options.oci = types.submoduleWith`) as the deliberate declaration site. |
| 11 | Anti-pattern: `specialArgs` pass-thru | WARN | `nix/modules/deploy/nix-oci/options/containers.nix:69-77` passes `nix2container`, `ociLib`, `ociNixOSModules`, `nixLibNixosModule` via submodule `specialArgs`. `_module.args.nix2container` used in `compose.nix:41,56,74`. Rationale: the deploy container submodule is a NixOS submodule (not a top-level flake-parts module), so it cannot read the top-level `config` directly. Documented tradeoff, not a lapse; still worth revisiting if a top-level `config.oci.internal.*` route can replace it. |
| 12 | Anti-pattern: lower-level module name proliferation | PASS | Deploy side merges under a small handful of names: `nix-oci-enable`, `nix-oci-containers`, `nix-oci-backend`, `nix-oci-load-services`, `nix-oci-run-services`, `nix-oci-snapshotter-config`, `nix-oci-test`, `soci-snapshotter`. Not one module per feature; features merge under `nix-oci-*` where appropriate. |
| 13 | Anti-pattern: gratuitous `enable` options | PASS (with caveat) | 20 `mkEnableOption` sites (grep of `nix/modules/`), but each one is either (a) an opt-in *feature toggle* users actually toggle (`cve.grype.enabled`, `signing.cosign.enabled`, `soci.enable`, `zstdChunked.enable`, `stargz.enable`, `lint.dockle.enabled`, `compliance.trivy.enabled`, `policy.conftest.enabled`, `sbom.syft.enabled`, `test.*.enabled`, `hardening.enable`, `oci.enable`), or (b) a top-level flake-control gate (`oci.enabled`, `oci.enableFlakeOutputs`, `oci.enableDevShell`). None are the "imported-by-default, must-opt-in-explicitly" NixOS-legacy pattern the canon warns against. |
| 14 | Anti-pattern: fanaticism (allow exceptions) | PASS | `_-prefixed` dirs are the exception mechanism (per canon "excluded from automatic importing"). `nix/lib/` contains helpers imported explicitly (`import ../../../../lib/discoverModules.nix { inherit lib; }`). BDD `.test.nix` files are excluded from import-tree and only re-imported by `test-collector.nix`. |
| 15 | `import-tree` default filter is left intact (no `.initFilter` unless needed) | PASS | No `.initFilter` calls in the repo. `.filterNot` is used only where the caller has a real reason (`examples.nix` excluding home-manager / probe examples from the root flake to keep `nix flake show` clean). |
| 16 | flake-parts "focused units per file" | PASS | Root flake is 144 lines, split across `nix/module.nix` (top-level glue), `nix/flake-module.nix` (public consumer module), `nix/test-flake-module.nix` (test infra), `nix/templates.nix`, `nix/docs.nix`, `nix/examples.nix`, `nix/treefmt.nix`. |
| 17 | Uses adjacent denful ecosystem tools where relevant | FAIL | `flake-file` not used (inputs are hand-declared in `flake.nix`). `checkmate` not used (custom `treefmt` module + `nix-lib` handles unit-testing). `fastest` not used (no parallel `nix-unit` runner). `dendrix` not referenced (repo could be listed there as a container-oriented aspect). Not blocking, but leaves adoption of the ecosystem incomplete. |
| 18 | Repo participates in the ecosystem (listed on `dendrix`, forum thread, etc.) | FAIL | Not linked from [mightyiam/dendritic real-examples list](https://github.com/mightyiam/dendritic#real-examples). Would be a natural fit as a domain-specific dendritic library (containers). |
| 19 | Every top-level module uses the top-level `config` for cross-file wiring, not injected values | WARN | Mostly PASS at the flake-parts level (see e.g. `checks.nix` reading `config.oci.flake.checks`, `apps.nix` reading `config.oci.flake.apps`). WARN because of the `specialArgs` pass-thru in item 11 and the `_module.args.nix2container` injection in `compose.nix`. |
| 20 | Non-module helpers use a naming scheme that excludes them from auto-import | PASS+ | Repo formalizes the canon's `*.pkg.nix` suggestion into a **three-way suffix router**: `*.nix` = option module, `*.lib.nix` = library-only module, `*.test.nix` = BDD spec. Preset filters in `nix/lib/discoverFilters.nix`. Goes beyond the canon. |

---

## 4. Gaps to close

Prioritized. Each item names the canon rule or ecosystem tool it addresses.

### HIGH

- **G1. Reduce `specialArgs` threading on the deploy submodule.**
  Rule: [Anti-pattern: `specialArgs` pass-thru](https://github.com/mightyiam/dendritic#specialargs-pass-thru).
  Evidence: `nix/modules/deploy/nix-oci/options/containers.nix:65-79` threads `nix2container`, `ociLib`, `ociNixOSModules`, `nixLibNixosModule` into `types.submoduleWith { specialArgs = ...}`. `compose.nix` further sets `_module.args.nix2container` at three call sites.
  Action: expose these as top-level `config.oci.internal.*` options (they already partially exist under `nix/modules/oci/internal/`), then read them in the submodule via `globalConfig` (which the repo already passes; see `perContainer.nix:124-127`). This is the exact refactor the canon endorses ("every file can also read from the top-level `config`. This makes the sharing of values between files seem trivial in comparison"). Even if you keep one `specialArg` for `pkgs`/`system` (which are legitimately per-system-scoped), the other four can move.

### MEDIUM

- **G2. Consolidate the three recursive `readDir` walkers into one shared helper.**
  Rule: not a canon rule; internal DRY concern.
  Evidence: `nix/lib/discoverModules.nix`, `nix/modules/deploy/nix-oci/nixos/_test/default.nix`, and `nix/modules/deploy/nix-oci/options/_snapshotter/default.nix` each implement the same recursive walker with the same "skip `_`-prefixed, filter by suffix, exclude `default.nix`" rules. They are **not** duplicating `import-tree`: `import-tree` unconditionally excludes paths containing `/_` (see the README: "Paths containing `/_` (an underscore starting any path segment) are ignored"), so the two `_test/` and `_snapshotter/` walkers exist precisely because they need to reach inside a `_`-prefixed subtree that `import-tree` deliberately skips. The consolidation is internal.
  Action: rewrite the two `default.nix` files as `import ../../../../../lib/discoverModules.nix { inherit lib; } ./.` (they will need `lib` in scope, which is trivial since they are already evaluated as `let ... in`-shaped Nix). Keep the semantics identical (recurse into non-`_` subdirs, keep `.nix` files, skip `default.nix`), delete ~40 lines of duplicated `builtins.readDir` code. Do not touch `nix/lib/discoverModules.nix` itself; it is doing exactly what it should.

- **G3. Adopt `denful/flake-file` for `flake.nix` inputs.**
  Rule: ecosystem principle "Define flake inputs as typed Nix module options. Regenerate `flake.nix` with one command." [source](https://denful.dev/ecosystem/overview/).
  Evidence: `flake.nix:3-22` hand-declares 6 inputs. `flake-file` would move these into a typed `flake.inputs.*` option tree and give you a `just flake-file` regenerator so consumers writing extension modules can add inputs without touching the root `flake.nix`. Small, mechanical, aligned with the ecosystem.

- **G4. Replace ad-hoc unit-test infrastructure with `checkmate` (or `fastest` for parallel runs).**
  Rule: ecosystem principle "CI with checkmate, real test suites" [source](https://denful.dev/ecosystem/overview/).
  Evidence: `nix-lib` currently handles unit tests via `flake.tests` (`nix/flake-module.nix:23-33`). If `nix-lib.tests` is already `nix-unit`-compatible, wrapping it in `checkmate` (which bundles `treefmt` + `nix-unit` and is zero-dep) or handing the discovery to `fastest` (parallel `nix-eval-jobs`-based runner) could speed up the BDD suite that the doc `MEMORY.md` mentions is currently a bottleneck. This is optional; the BDD-VM approach in the repo is already excellent, but for the *pure Nix* unit-test layer this is a straight win.

- **G5. Move `nix/lib/discoverFilters.nix` presets into a chainable `.addAPI` extension.**
  Rule: [import-tree `.addAPI`](https://import-tree.denful.dev/reference/api/#addapi-attrset): "Extend the import-tree object with new methods."
  Evidence: `nix/lib/discoverFilters.nix` defines `options` / `lib` / `test` filename filters. These are exactly the domain-specific API extensions `.addAPI` is designed for. Sketch:
  ```nix
  # in flake.nix
  _module.args.import-tree = inputs.import-tree.addAPI {
    options = self: self.filter (n: hasSuffix ".nix" n && !hasSuffix ".lib.nix" n && !hasSuffix ".test.nix" n && baseNameOf n != "default.nix");
    lib     = self: self.filter (n: hasSuffix ".lib.nix" n);
    tests   = self: self.filter (n: hasSuffix ".test.nix" n);
  };
  ```
  Then downstream code can write `(import-tree.tests ../containers/_tests).files` instead of `discoverModules { dir = ...; filter = filters.test; }`, and the whole thing shares the import-tree filter machinery you already depend on.

### LOW

- **G6. Register the repo as a dendritic real-example / dendrix aspect.**
  Rule: [dendritic real-examples list](https://github.com/mightyiam/dendritic#real-examples), [dendrix ecosystem entry](https://denful.dev/ecosystem/dendrix/).
  Action: open a PR against [`mightyiam/dendritic`](https://github.com/mightyiam/dendritic) adding `nix-oci` under "real examples", and (optionally) a `dendrix` submission tagging this as a container-oriented aspect.

- **G7. Cross-link `docs/` to the canon so contributors know the vocabulary.**
  Rule: ecosystem "Documented". A short `docs/content/explanation/dendritic-pattern.md` naming the pattern, linking to the canon, and enumerating the two extensions this repo adds (one-option-per-file, filename-suffix router) would onboard newcomers faster and make the design language shared with the ecosystem.

- **G8. Consider renaming `oci.enabled` / `enableFlakeOutputs` / `enableDevShell` to line up with the "enable options anti-pattern" spirit.**
  Rule: [Anti-pattern: `enable` options](https://github.com/mightyiam/dendritic#enable-options): "In most cases, importing a module should enable the feature that it provides."
  Evidence: `nix/modules/oci/namespace.nix:9-22` and the pattern in `flake-module.nix` require consumers to write `oci.enabled = true;` before anything happens. The canon's ideal is "importing the module enables the feature". Practical caveat: the repo intentionally offers `enableFlakeOutputs = false` for extenders who want the library without the ~160 apps/packages/checks. That is a real product decision, not a lapse. **Low priority**: keep the gate, but document *why* in a comment that references the canon so the divergence is deliberate.

---

## 5. Strengths to keep (and why they matter)

- **Cross-module-class scope isolation via `_`-prefix + explicit re-gather.** `import-tree`'s hard rule ("Paths containing `/_` are ignored") means underscore-prefixed subtrees are invisible to the top-level flake-parts walk. The repo uses this deliberately: `_test/` holds NixOS module files that must be gathered into `flake.modules.nixos.nix-oci-test` (evaluated in the NixOS module class, not flake-parts); `_snapshotter/` holds submodule-option files that must be gathered into a `submoduleWith` mounted at `options.oci.snapshotter`; `_tests/` holds `.test.nix` BDD specs that are re-imported by `test-collector.nix` only. In every case, the explicit walker in `default.nix` re-collects the files into the *correct module scope* that the top-level `import-tree` cannot deliver them to. This is a pattern the canonical Dendritic examples do not have a story for (they walk a single module class per tree), and it is exactly what the anti-pattern "not declaring options" is pushing you toward: declare the right option, then feed the right files into it. Keep it, document it in a `README` next to each `_*/default.nix`, and consider promoting the walker to a shared helper (G2).

- **One option per file, one option path per file path.** The canon says "one feature per file"; the repo takes it further: `_oci/cve/grype/enabled.nix` -> `options.cve.grype.enabled`. This makes the option tree navigable via `find`, makes each file trivially rebasable, and makes conflicts impossible in review because every option lives in its own file. This is worth documenting as the repo's own idiom on top of the canon.

- **Filename-suffix router (`*.nix` / `*.lib.nix` / `*.test.nix`) via `nix/lib/discoverFilters.nix`.** Cleaner than the canon's `.pkg.nix` suggestion because it scales to three categories, not one, and the tests are co-located with the options they test (compare `_options/hardening/seccomp.nix` next to `_tests/hardening/seccomp.test.nix`). Even so, see G5: this could be an `import-tree` `.addAPI` extension instead of a separate helper.

- **`deferredModuleWith` with `staticModules` for auto-discovered submodule options** (`nix/modules/oci/containers/perContainer.nix:35-65`, mirrored in `perTag.nix` and `multiArch/perArch.nix`). This is the piece the canon calls out as "the pattern" and the repo implements it correctly at three nesting levels (container, tag, arch), letting BDD tests get real `getSubOptions` visibility for `nixosOptionsDoc` generation. Non-trivial and correct.

- **Partitioned dev/docs outputs** (`flake.nix:44-142`). Uses `flake-parts.flakeModules.partitions` to keep the extender-facing flake surface small (`oci.enableFlakeOutputs = false` in dev) while still running the full BDD suite from the root via `xi check`. This is the kind of "no lock-in / composable" hygiene the [ecosystem principles](https://denful.dev/ecosystem/overview/) actually reward, even though the canon doesn't mention partitions.

- **Shared eval for flake-parts + NixOS**. `nix/lib/eval-container.nix` is a single container-eval consumed from both the flake-parts side (docs, tests, checks) and the deploy side (NixOS/HM `systemd.services`). This is the *practical* answer to the canon's "sharing of values between files seem trivial" claim: the trivia is the *option tree*, and this repo shares the tree, not just isolated values.

---

## 6. Sources

- <https://denful.dev/> - Landing page; enumerated the ecosystem tools and their one-line pitches.
- <https://denful.dev/ecosystem/overview/> - Full ecosystem inventory (import-tree, flake-file, checkmate, dendrix, fastest, den, ...) and shared design principles.
- <https://denful.dev/ecosystem/import-tree/> - Ecosystem entry for import-tree; short conventions summary.
- <https://github.com/mightyiam/dendritic> - **Canonical pattern spec**; every core rule, benefit, and anti-pattern quoted in section 2 comes from here.
- <https://github.com/denful/import-tree> - `import-tree` README with the canonical flake-parts wiring example and the `/_` default-filter statement.
- <https://import-tree.denful.dev> - `import-tree` Starlight docs site (root).
- <https://import-tree.denful.dev/guides/dendritic/> - Explicit statement of the `/_` convention and dendritic-with-flake-parts snippet.
- <https://import-tree.denful.dev/guides/filtering/> - Detailed `.filter` / `.filterNot` / `.match` / `.matchNot` / `.initFilter` semantics.
- <https://import-tree.denful.dev/reference/api/> - Full API reference (`.map`, `.addPath`, `.addAPI`, `.addScoped`, `.leaves`, `.files`, `.pipeTo`, `.result`, `.new`).
- <https://flake.parts/> - flake-parts landing page; only relevant quote is "Split your `flake.nix` into focused units, each in their own file", used as ecosystem endorsement.
- Local repo: `/home/juliendauliac/ghq/github.com/Dauliac/nix-oci` - cross-checked against `flake.nix`, `nix/module.nix`, `nix/flake-module.nix`, `nix/modules/**`, `nix/lib/discoverModules.nix`, `nix/lib/discoverFilters.nix`, and project `MEMORY.md`.
- Research cache (kept for reproducibility): `/home/juliendauliac/ghq/github.com/Dauliac/nix-oci/.claude/research-cache/{dendritic-README.md,import-tree-README.md,import-tree-docs/}`.

## Context

See `proposal.md` for motivation. Constraints that shape the design:

- **Test harness already exists.** `test-vm.nix` boots a minimal NixOS VM, discovers all `.test.nix` files via `test-collector.nix`, and dispatches to pytest via `_python-gen.nix`. New coverage should reuse this pipeline rather than introduce a second harness.
- **Assertion vocabulary is limited.** `_option-test-spec.nix` currently exposes `imageConfig`, `labels`, `fileContains`, `fileNotContains`, `succeeds`, `fails`, `httpResponds`, `processEnv`, `containerInspect`, `systemdProps`, plus a `runtime` escape hatch. Several new verifications (syscall blocked, DNS resolution fails, TLS handshake fails, SOCI zTOC present, firewall port open, manifest digest matches) don't naturally fit any of these; they need new helpers.
- **Podman is the default runtime.** Docker is a toggle path via `config.test.oci._vmBackend`. Introducing docker as a first-class test target must not double the test time; it should be gated to a narrow set of scenarios that specifically exercise docker-only behavior (containerd + SOCI snapshotter).
- **Single-runner CI can't host multi-arch native builds.** GitHub Actions provides `ubuntu-latest` (x86_64); building aarch64 natively needs either a remote builder or binfmt/qemu. The design must keep multi-arch out of the default gate.
- **Reproducibility test is inherently multi-run.** Nix caches by output hash; a single evaluation naturally memoizes. Building twice requires either a rebuild flag, a clean sandbox, or comparing two independently-produced store paths from different builders.
- **Coherence assertions live in module-eval time.** They're `assertions` and `warnings` on a NixOS-like eval, not derivations. Testing them requires importing the module with a bad config and asserting that `nixosConfigurations.<name>.config.assertions` contains a matching entry, then that the eval throws when the assertion isn't filtered out.
- **Container probes rely on non-hermetic execution** (real podman daemon or a VM). The existing exclusion list in `tests/flake.nix:55-61` was added because probe examples can't run in a pure Nix build. Un-excluding them requires wiring through `test-apps.nix` (the VM-boot smoke harness), not through the pure `nix build` path.

## Goals / Non-Goals

**Goals:**

- Every requirement in the five spec files becomes at least one `.test.nix` scenario, discovered automatically by `test-collector.nix` when the file lands in `_tests/`.
- Runtime tests reuse the existing pytest harness where the vocabulary fits (`processEnv`, `succeeds`, `fails`, `httpResponds`) and extend `_python-gen.nix` with new helpers where it doesn't.
- Coherence-assertion regression tests fail the build if any of P2..S4 stops firing, so the assertion logic itself is guarded against silent regressions.
- Docker backend, SOCI snapshotter, and home-manager / system-manager modules run in the same VM harness (parameterized), not in a separate harness.
- Multi-arch tests exist and are runnable, but are excluded from `ci.yml`'s default job.
- No production module code is touched; only test infrastructure and test specs.

**Non-Goals:**

- Not a rewrite of `test-vm.nix` or `_python-gen.nix`. Extensions are additive.
- Not adding a new test runner (no rspec, no bats, no go test).
- Not verifying real GPU behavior (no GPU hardware in CI). GPU coverage is limited to inspect + env-var checks per the spec.
- Not replacing existing passing tests; only extending them.
- Not implementing multi-arch remote builders. The multi-arch capability defines the tests; wiring the CI runner is out of scope for this change.
- Not upgrading dependency versions except where required to unblock `home-config.test.nix` (nixpkgs `lib/services/lib.nix` compat).

## Decisions

### D1. Assertion vocabulary extensions live in `_python-gen.nix`, not in shell wrappers

**Choice:** Extend `_option-test-spec.nix` with new typed assertions (`syscallBlocked`, `fsWriteBlocked`, `dnsResolutionFails`, `tlsHandshakeFails`, `envVarSet`, `sociZtocPresent`, `manifestDigestMatches`, `firewallPortOpen`) and generate the corresponding pytest code from `_python-gen.nix`.

**Alternative considered:** Use only the existing `runtime` escape hatch (arbitrary shell) so no schema change is needed.

**Rationale:** Typed assertions produce readable pytest and readable failure output ("mount syscall blocked: EPERM as expected" vs "shell script exited 1"). They also let the schema validate spec files at load time. The one-time cost of adding ~8 typed helpers pays off across ~50 new scenarios.

### D2. Coherence-assertion regression via `builtins.tryEval` on module-eval

**Choice:** For each P2..S4 assertion, add a scenario that imports a container module with the contradictory config, wraps the eval in `builtins.tryEval`, and asserts that (a) `tryEval` reports a failure and (b) the error message contains the assertion tag ("P2", "S1", etc.).

**Alternative considered:** Move the assertion logic out of `_nixos-oci/hardening/coherence.nix` into a pure function that can be tested by `nix-unit`.

**Rationale:** The alternative is a bigger refactor and moves logic away from the module system, which is where the assertions naturally belong (they read the module's `config` shape). `tryEval` gives regression coverage without moving code. If a future assertion happens to be a warning-only trace (D2..G3), we assert on the presence of the trace line in the eval log instead of `tryEval`.

### D3. Docker backend as a VM-parameter matrix

**Choice:** Parameterize `test-vm.nix` on `_vmBackend`. Run the full deploy suite once with podman (default) and re-run only a small opt-in subset with docker. The docker subset covers exactly the things that podman can't exercise: SOCI snapshotter (containerd-only), and the docker-specific loader path.

**Alternative considered:** Run every deploy scenario twice (podman + docker).

**Rationale:** Doubling the deploy suite time isn't justified. Nearly all deploy behavior is backend-agnostic; only the loader script and the snapshotter path differ.

### D4. Un-excluding container probes: promote example flakes to `bdd-apps`

**Choice:** Remove the four `minimalist-with-{amicontained,cdk,deepce,linpeas}` entries from `tests/flake.nix:55-61`. Ensure `test-apps.nix` treats their apps as valid smoke tests. Add a per-probe `runtime`-level scenario in a new `_tests/probes/*.test.nix` that boots the container in the VM and runs the probe against it, then asserts the probe's stdout contains its signature banner.

**Alternative considered:** Keep probes excluded, add a separate `probes-vm-check`.

**Rationale:** The exclusion was for "probes can't run in a pure `nix build`", which was true of the old pure test path. The VM harness (`bdd-apps`, `bdd-vm`) is exactly where probes should run since it has a real podman/docker daemon. One place to run all container-runtime tests keeps the picture simple.

### D5. Pipeline machinery test uses a synthetic step

**Choice:** Register a synthetic test-only step in the pipeline that emits a distinctive marker file at build time and a distinctive marker string at runtime. Toggle `defaultBackend` and per-step `backend` to assert the marker appears in the expected surface (gate derivation vs flake apps) for each combination.

**Alternative considered:** Test with a real tool (say Dockle) and assert on its outputs.

**Rationale:** Coupling the pipeline-machinery test to a real tool's output makes the test flaky when the tool changes. A synthetic step exercises just the wiring.

### D6. Reproducibility: two `nix build` invocations, compare `nix path-info --json`

**Choice:** Add a check derivation that runs `nix build` twice against a small fixture container (once with `--rebuild`), collects both output paths, and compares the OCI manifest digest reported by `nix path-info --json` (or by parsing the manifest file inside the output). Fail if they differ.

**Alternative considered:** Use `nix build --repeat 1 --check`, which is the built-in Nix mechanism for reproducibility.

**Rationale:** `--repeat` / `--check` runs the derivation twice inside the same builder invocation, which does catch most reproducibility issues, but the manifest digest we want to compare is inside a JSON file, not the output hash. A dedicated check gives clearer failure output and works uniformly for reproducibility of any file the manifest points at.

### D7. `home-config.test.nix` unblock via nixpkgs pin, not upstream patch

**Choice:** Pin nixpkgs at the input granularity (a follower to a known-good ref for home-manager evaluation) rather than patching home-manager to work with the current nixpkgs.

**Alternative considered:** File the upstream fix, wait for merge, then remove the pin.

**Rationale:** The upstream API drift isn't this repo's problem to fix; a pin unblocks CI now, and the follower can be dropped when the upstream normalizes.

### D8. Multi-arch as a separate flake check, opt-in in CI

**Choice:** Expose `checks.<sys>.multi-arch` as a top-level check that's NOT included in `nix flake check`'s default set (via `_type = "check"` on a distinct attr, or via a separate flake output). Trigger from `ci.yml` only under `workflow_dispatch` with an input flag.

**Alternative considered:** Always run multi-arch under emulation via binfmt/qemu.

**Rationale:** Emulated aarch64 build of a real container is slow (10x slower than native) and unreliable in Actions. Manual dispatch is honest about the cost.

### D9. Test spec taxonomy: one file per capability's requirement group

**Choice:** Place new specs under `_tests/<scope>/` mirroring the capability path: `_tests/runtime/{seccomp,apparmor,capabilities,rootfs,privileges,dns,tls,allocator,glibc-tunables,hwcaps,soci,compression,gpu,probes-framework,probes-e2e}.test.nix`, `_tests/pipeline/{conftest,dockle,dive,syft,trivy-secret,trivy-cve,grype,vulnix,cosign,compliance-trivy,cst,cst-coherence,dgoss,machinery}.test.nix`, `_tests/deploy/{home-manager,system-manager,docker-backend,soci,postgresql,httpd,bind,dnsmasq,postfix,phpfpm,wiring-ports,wiring-env,wiring-volumes,wiring-deps}.test.nix`, `_tests/invariant/{reproducibility,coherence-assertions,label-network,label-kubernetes,label-runtime,label-nix,label-performance,label-security,label-oci-annotations}.test.nix`, `_tests/multi-arch/{merge,cross-compile,emulated}.test.nix`.

**Alternative considered:** Keep the current flat layout.

**Rationale:** The audit produced 11 scopes; the specs collapse into 5 capabilities. Mirroring the capability structure in `_tests/` keeps the mapping obvious and makes it easy to run "just the runtime-behavior tests" via a glob-based Taskfile target.

## Risks / Trade-offs

- **[VM boot time balloons past CI budget]** -> Mitigation: keep each new `runtime`-level scenario in a shared VM where possible (batch scenarios into the fewest VMs the harness supports), and audit the bdd-vm total time after landing each capability. If wall time exceeds ~15 minutes on `ubuntu-latest`, split the check into a fast and a slow half; slow half runs on `workflow_dispatch` or nightly.
- **[Coherence-assertion regression tests are tightly coupled to the assertion identifiers (P2, S1, ...)]** -> Mitigation: name the fixture files after the assertion tags (`coherence-p2.test.nix`), and add a comment in `_nixos-oci/hardening/coherence.nix` above each assertion pointing at its test file. When someone renames an assertion, grep finds the test.
- **[Docker backend path may reveal latent bugs unrelated to this change]** -> Mitigation: land docker-backend scenarios behind a `experimental = true` flag first, collect one release cycle of green, then flip them into the default set.
- **[Removing probe exclusions may leak non-hermetic behavior into `nix flake check`]** -> Mitigation: run probes only from `bdd-apps` / `bdd-vm` VMs (which are already non-pure by construction). Don't add probe checks to any derivation that runs in the Nix sandbox.
- **[Reproducibility test may flake if some upstream dep is non-deterministic]** -> Mitigation: start with a minimal fixture (single-package container, no service adapter) so any flake failure isolates the source. If a real upstream dep is non-deterministic, either exclude it from the fixture or file the upstream bug and mark the scenario `known-flaky` (excluded from CI, runnable locally).
- **[Home-manager unblock may drift again on next nixpkgs bump]** -> Mitigation: add an assertion in `home-config.test.nix` that fails loudly if the API check trips, so a future nixpkgs bump surfaces the drift immediately instead of silently disabling the test again.
- **[Test-time growth impacts contributor loop]** -> Mitigation: `task test:unit` remains fast (Nix eval only); `task test:vm` gets slower. Document the split in `Taskfile.yaml` help so contributors know which target to run for their loop.

## Migration Plan

Not applicable. No production behavior changes, no data migration, no deprecated APIs. Rollout is per-capability: land runtime-behavior first (highest security value), then pipeline-behavior (highest per-feature-count coverage), then deploy-runtime, then build-invariant, then multi-arch (last, since it needs the opt-in CI flag).

## Open Questions

1. **Test-time budget.** The acceptable wall-clock ceiling for `nix flake check` after this change lands needs to be decided. Current baseline needs measurement. Committing to a hard ceiling now would let us size the split between default-CI and opt-in-CI up front instead of after the fact.
2. **Nixpkgs pin scope for `home-config.test.nix`.** Decide whether to pin only the follower used by home-manager tests or bump the whole tree. Depends on how far the API drift is and whether other tests care about the same nixpkgs revision.

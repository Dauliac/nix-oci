## Why

A parallel-agent coverage audit (root bead `docs-ci-deploy-2pj`, 11 scope beads) found that CI guards option shape (eval), image config coherence (inspect), and 3 service adapters at deploy level, but doesn't guard the actual behavior of most user-visible features. Concretely, 0 of 9 hardening features are verified at runtime, all 12 performance tests are eval-only, all 15 validation-pipeline tools ship with no behavioral test, all 4 container probes are excluded from CI, home-manager and system-manager deploy modules have no runtime coverage, the docker backend toggle is never exercised, and the bit-for-bit reproducibility claim on every image is never checked. A user can safely enable hardening.seccomp = "strict", ship, and CI would not catch a regression that silently disabled the seccomp filter, because the test only checks that a label was set. This change closes that gap by adding runtime and behavioral verification wherever a feature's effect can be observed inside the existing VM harness.

## What Changes

- Add runtime-level BDD tests for every hardening feature (seccomp / apparmor / capabilities / rootfs / noNewPrivileges / disableDns / noTlsTrustStore) that exercise the effect from inside a running container and assert the expected syscall / mount / DNS / TLS behavior.
- Add runtime/inspect tests for every performance feature (allocator LD_PRELOAD injection, glibc tunables, hugepages, hwcaps, startup, compression, turbo, SOCI zTOC generation, span size).
- Add inspect-level tests for GPU features (label + env + library presence).
- Add per-tool behavioral tests for all 15 validation-pipeline tools (conftest, dockle, dive, syft, trivy-secret, trivy-cve, grype, vulnix, cosign, compliance-trivy, CST, CST-coherence, dgoss, plus pipeline machinery + defaultBackend routing).
- Un-exclude the 4 container-probe example flakes and gate them via `bdd-apps` so amicontained / CDK / DEEPCE / linPEAS produce proof-of-delivery.
- Add coherence-assertion regression tests that verify each P2 through G3 assertion in `_nixos-oci/hardening/coherence.nix` fires when its contradiction is present.
- Add reproducibility test: two independent builds of the same container produce identical manifest digests.
- Add deploy-level runtime tests for home-manager and system-manager modules (loader + runner + healthcheck), and add a docker-backend variant that reuses the existing NixOS harness with `_vmBackend = "docker"`.
- Add SOCI snapshotter deploy test: enable SOCI + docker backend in the VM, boot the snapshotter service, verify a lazy-pull path works end-to-end.
- Add deploy-level tests for the 7 untested service adapters (PostgreSQL with writable tmpfs, httpd, BIND, dnsmasq, Postfix, PHP-FPM; vsftpd deferred by design since it has no healthcheck).
- Add "triple-write" wiring tests for `ports` (OCI ExposedPorts + runner --publish + firewall allowedTCPPorts) and dual-write for `environment` (OCI Env + runner --env) so all destinations are asserted in a single test.
- Add inspect-level label-coherence tests covering the six label namespaces currently unit-only: `network.*`, `kubernetes.*`, `runtime.*`, `nix.*`, `performance.*`, `security.*`, plus the missing `org.opencontainers.image.*` fields (description, licenses, url, authors, documentation, base.name).
- Add multi-arch tests (native-parallel, cross-compile, emulated) gated behind an opt-in flag so single-builder CI still passes.
- Add framework tests for `mkContainerProbe` and `mkHermeticContainerProbe` (needsShell/busybox co-mount, failPatterns/warnPatterns, `NIX_OCI_REPORT_DIR` report emission).
- Wire the `home-config.test.nix` FIXME (nixpkgs `lib/services/lib.nix` compatibility) by pinning or adapting so the file is no longer disabled.
- Fix `nixos-config.test.nix:87-89` PostgreSQL blocker by adding writable tmpfs support to the deploy-level BDD spec.

Non-breaking. No user-facing API removal. All additions are new `.test.nix` specs, new BDD assertion helpers, and one extension to the `_vmBackend` toggle path (already declared but not exercised).

## Capabilities

### New Capabilities

- `testing/runtime-behavior-verification`: runtime-level BDD assertions for hardening, performance, GPU, and the four container probes. Covers seccomp/apparmor/caps/rootfs/noNewPrivileges/disableDns/noTlsTrustStore behavioral checks, allocator LD_PRELOAD verification, SOCI zTOC generation, hwcaps library selection, and per-probe report emission.
- `testing/pipeline-behavior-verification`: behavioral tests for the 15 tools registered in `oci.pipeline.steps`, the pipeline machinery (step registry, `defaultBackend` routing, mkStamp/mkScript wiring, gate assembly), and the CST coherence autogeneration round-trip (declared config -> generated metadataTest JSON).
- `testing/deploy-runtime-verification`: deploy-level runtime tests for home-manager and system-manager modules, docker-backend variant of the NixOS harness, SOCI snapshotter deploy + lazy-pull, the 6 currently-untested service adapters (postgresql, httpd, bind, dnsmasq, postfix, phpfpm), and dual/triple-write runner-service wiring assertions.
- `testing/build-invariant-verification`: reproducibility test (two builds -> identical digest), coherence-assertion regression tests (P2-G3), inspect-level label coherence for the 6 currently unit-only label namespaces, plus the missing `org.opencontainers.image.*` fields.
- `testing/multi-arch-verification`: opt-in multi-arch build tests covering native-parallel, cross-compile, and emulated paths; excluded from default `nix flake check` because single-builder CI can't host them without infra changes.

### Modified Capabilities

None. This is a purely additive change: no existing spec-level requirement is altered.

## Impact

- **Test files added**: ~55 new `.test.nix` specs across `nix/modules/oci/containers/_tests/{hardening,performance,gpu,pipeline,probes,deploy,wiring,labels}/`. All autodiscovered by `test-collector.nix` (no wiring change).
- **Test infrastructure changes**:
  - Extend `_python-gen.nix` and `_option-test-spec.nix` to support new assertion types where needed: `syscallBlocked`, `fsWriteBlocked`, `dnsResolutionFails`, `tlsHandshakeFails`, `envVarSet`, `sociZtocPresent`, `manifestDigestMatches`, `firewallPortOpen`.
  - Extend `test-vm.nix` VM builder to optionally boot with a writable tmpfs for a container's declared `StateDirectory` paths (unblocks PostgreSQL).
  - Extend `test-vm.nix` to support running probes as verification tools inside runtime scenarios (mount amicontained/CDK/etc. into a container-under-test and grep output).
  - Extend `test-apps.nix` to include probe apps for containers that opt into probe checks.
- **CI workflow changes**: `ci.yml` unchanged (BDD tests autopicked up by `nix flake check`). One new opt-in job for `checks.<sys>.multi-arch-vm` gated behind a workflow-dispatch flag.
- **Test time impact**: Runtime and deploy tests are the slowest tier. Expect `bdd-vm` runtime to grow from current baseline to roughly 2 to 3x (rough estimate, to be measured). Mitigation: keep runtime scenarios small (single-container VMs, oneshot mode where possible) and parallelize inside the pytest harness (`-n` bump).
- **Nixpkgs compat**: unblocking `home-config.test.nix` may require pinning nixpkgs or working around the `lib/services/lib.nix` API drift. Design doc will lay out the two paths.
- **Beads**: root bead `docs-ci-deploy-2pj` and synthesis bead `docs-ci-deploy-0cb` remain open; this change's `tasks.md` will be decomposed via `beads-plan plan openspec/changes/runtime-behavioral-test-coverage` after archive.
- **No production code touched.** Only test infrastructure and test specs. Production module behavior doesn't change.
- **Docs impact**: `docs/content/test-reference/` gains entries for the new assertion helpers; `docs/content/security/hardening.md` and `docs/content/security/container-probes.md` gain "Verified by" backlinks per the project's documentation convention.

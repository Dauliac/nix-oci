## 1. Test infrastructure extensions

- [ ] 1.1 Extend `nix/modules/oci/testing/_option-test-spec.nix` with new assertion types (`syscallBlocked`, `fsWriteBlocked`, `dnsResolutionFails`, `tlsHandshakeFails`, `envVarSet`, `sociZtocPresent`, `manifestDigestMatches`, `firewallPortOpen`) and verify a fixture `.test.nix` using each new assertion type evaluates without schema error.
- [ ] 1.2 Extend `nix/modules/oci/testing/_python-gen.nix` to emit pytest code for each new assertion type from 1.1, and verify the generated pytest for one fixture per assertion type parses and imports successfully in a dry run.
- [ ] 1.3 Add writable-tmpfs support in `nix/modules/oci/testing/test-vm.nix` for containers that declare a `StateDirectory` (parameterized per-test), and verify a fixture PostgreSQL container reaches `active` in the VM.
- [ ] 1.4 Parameterize `nix/modules/oci/testing/test-vm.nix` on `_vmBackend` (podman | docker) so a single deploy scenario can be re-run under both, and verify the existing `nixos-caddy.test.nix` still passes under podman and passes under docker.
- [ ] 1.5 Extend `nix/modules/oci/testing/test-apps.nix` to include container-probe apps (amicontained / CDK / DEEPCE / linPEAS) when the container opts into probes, and verify the smoke run of one probe app succeeds inside the VM.
- [ ] 1.6 Un-exclude the four `minimalist-with-{amicontained,cdk,deepce,linpeas}` example flakes in `tests/flake.nix:55-61`, and verify `nix flake check` picks up their apps as valid targets.
- [ ] 1.7 Unblock `nix/modules/oci/containers/_tests/home-config.test.nix` by pinning nixpkgs (per design D7) so `home-manager` evaluation succeeds; verify the eval-level scenario runs (no longer skipped) and add a load-bearing assertion that trips loudly if the nixpkgs API drifts again.

## 2. Runtime hardening tests (spec: testing/runtime-behavior-verification)

- [ ] 2.1 Add `_tests/runtime/seccomp.test.nix` covering strict/moderate/custom-syscall scenarios, and verify each scenario fails at the expected syscall (mount, unshare) when the profile is applied and succeeds for allowed syscalls.
- [ ] 2.2 Add `_tests/runtime/apparmor.test.nix` for the /proc write-deny scenario, and verify a container with the profile applied is denied and one without succeeds.
- [ ] 2.3 Add `_tests/runtime/capabilities.test.nix` reading `/proc/1/status` CapEff bitmask for both drop-ALL default and add-NET_BIND_SERVICE, and verify the bitmask matches the declared config.
- [ ] 2.4 Add `_tests/runtime/rootfs.test.nix` asserting `touch /new-file` fails with EROFS, and verify the assertion trips.
- [ ] 2.5 Add `_tests/runtime/privileges.test.nix` with a setuid binary that prints its euid, and verify the euid is the caller's uid (4000) not 0 when `noNewPrivileges = true`.
- [ ] 2.6 Add `_tests/runtime/dns.test.nix` using a small getaddrinfo tool, and verify the tool exits nonzero when `hardening.disableDns = true` and succeeds when it's false.
- [ ] 2.7 Add `_tests/runtime/tls.test.nix` running `curl https://www.google.com`, and verify curl reports cert-verification failure when `hardening.noTlsTrustStore = true`.

## 3. Runtime performance tests

- [ ] 3.1 Add `_tests/runtime/allocator.test.nix` reading `/proc/1/environ` for each allocator variant (jemalloc, mimalloc, tcmalloc, snmalloc), and verify LD_PRELOAD ends in the expected `.so` for each.
- [ ] 3.2 Add `_tests/runtime/allocator-config.test.nix` verifying `MALLOC_CONF` (and equivalents for other allocators) reach `/proc/1/environ`.
- [ ] 3.3 Add `_tests/runtime/glibc-tunables.test.nix` verifying explicit and preset-expanded `GLIBC_TUNABLES` reach `/proc/1/environ`.
- [ ] 3.4 Add `_tests/runtime/hwcaps.test.nix` inspecting image layers for `glibc-hwcaps/x86-64-v3/` variant of a hwcaps-eligible library, and verify the variant is present when enabled and absent when disabled.
- [ ] 3.5 Add `_tests/runtime/soci.test.nix` pushing to the in-VM registry, inspecting the resulting OCI index for a SOCI v2 zTOC referrer, and verifying the configured `sociSpanSize` is honored.
- [ ] 3.6 Add `_tests/runtime/compression.test.nix` verifying manifest layer media types report `+zstd` when `compression = "zstd"` and stargz TOC entries when `gzip:estargz`.

## 4. GPU and container-probe tests

- [ ] 4.1 Add `_tests/runtime/gpu-labels.test.nix` covering `gpu.enable = true` label assertions and `gpu.runtimeLibraries` ELF-marker checks in the image, and verify each label and each library file is present.
- [ ] 4.2 Add `_tests/runtime/gpu-forward-compat.test.nix` asserting the CUDA compat library is present when `forwardCompat = true`, and verify it appears in the image layers.
- [ ] 4.3 Add `_tests/runtime/probes-framework.test.nix` unit-testing `mkContainerProbe` for `needsShell=true` busybox co-mount, `failPatterns` nonzero exit, `warnPatterns` warning emission, and `NIX_OCI_REPORT_DIR` report file, and verify each behavior.
- [ ] 4.4 Add `_tests/runtime/probes-e2e.test.nix` covering amicontained + CDK + DEEPCE + linPEAS end-to-end (probe app runs against the loaded container, output is captured and matched against the tool's signature banner), and verify each of the four probes produces output.

## 5. Pipeline behavior tests (spec: testing/pipeline-behavior-verification)

- [ ] 5.1 Add `_tests/pipeline/conftest.test.nix` covering built-in `oci.rego` rejection of `isRoot=true`, acceptance of `isRoot=false`, and `extraPolicyDirs` composition with a user rule, and verify each scenario fails or passes the gate as declared.
- [ ] 5.2 Add `_tests/pipeline/dockle.test.nix` covering a FATAL-triggering container that fails the gate and an ignore-list that passes, and verify both.
- [ ] 5.3 Add `_tests/pipeline/dive.test.nix` covering an intentionally-wasteful container that fails the dive threshold, and verify the gate fails at the dive step.
- [ ] 5.4 Add `_tests/pipeline/syft.test.nix` covering SBOM generation for a container containing `pkgs.hello`, and verify the CycloneDX JSON contains a `hello` component.
- [ ] 5.5 Add `_tests/pipeline/trivy-secret.test.nix` with a container that contains an AWS-key-shaped string, and verify the gate fails; also verify a clean container passes.
- [ ] 5.6 Add `_tests/pipeline/trivy-cve.test.nix` covering CVE scan output presence in `$NIX_OCI_REPORT_DIR` and ignore-file suppression of a specific CVE-ID, and verify both.
- [ ] 5.7 Add `_tests/pipeline/grype.test.nix` covering Grype CVE scan output presence, and verify the report is written.
- [ ] 5.8 Add `_tests/pipeline/vulnix.test.nix` covering Vulnix scan against the Nix closure, and verify the summary line is emitted.
- [ ] 5.9 Add `_tests/pipeline/cosign.test.nix` covering key-based sign + verify round-trip and annotation attachment, and verify signing produces a payload cosign verify accepts.
- [ ] 5.10 Add `_tests/pipeline/compliance-trivy.test.nix` covering CIS compliance summary output, and verify the summary contains passed/failed counts.
- [ ] 5.11 Add `_tests/pipeline/cst.test.nix` covering CST pass on a coherent image and fail on a mutated image (test-only mutator that strips an ExposedPorts entry), and verify each.
- [ ] 5.12 Add `_tests/pipeline/cst-coherence.test.nix` covering the autogenerated metadataTest for ports, user, entrypoint, labels, workdir, and volumes, and verify each user-declared field appears in the generated JSON.
- [ ] 5.13 Add `_tests/pipeline/dgoss.test.nix` covering a passing and a failing goss file, and verify dgoss exit codes match.
- [ ] 5.14 Add `_tests/pipeline/machinery.test.nix` registering a synthetic test step, toggling `defaultBackend` and per-step `backend` (per design D5), and verifying the marker appears in the expected surface (gate derivation vs flake apps) for each of the four combinations.

## 6. Deploy runtime tests (spec: testing/deploy-runtime-verification)

- [ ] 6.1 Add `_tests/deploy/home-manager.test.nix` booting the home-manager loader + runner + healthcheck, and verify both units reach active and the Podman quadlet reports `Type=notify`.
- [ ] 6.2 Add `_tests/deploy/system-manager.test.nix` applying a system-manager profile that includes the deploy module, and verify loader and runner both reach active.
- [ ] 6.3 Add `_tests/deploy/docker-backend.test.nix` reusing the `nixos-caddy` scenario with `_vmBackend = "docker"`, and verify the HTTP assertion still passes.
- [ ] 6.4 Add `_tests/deploy/soci.test.nix` deploying a SOCI-indexed image via containerd, and verify the snapshotter service is active and the container becomes ready before all layer bytes are fetched.
- [ ] 6.5 Add `_tests/deploy/postgresql.test.nix` with writable tmpfs from 1.3, and verify `psql -c 'SELECT 1'` returns `1`.
- [ ] 6.6 Add `_tests/deploy/httpd.test.nix` covering the `_nix_oci_health` endpoint, and verify HTTP 200.
- [ ] 6.7 Add `_tests/deploy/bind.test.nix` covering `dig version.bind chaos txt`, and verify the TXT record is non-empty.
- [ ] 6.8 Add `_tests/deploy/dnsmasq.test.nix` covering a hosts-entry lookup, and verify dig returns the configured IP.
- [ ] 6.9 Add `_tests/deploy/postfix.test.nix` covering `postfix status`, and verify it reports the master pid.
- [ ] 6.10 Add `_tests/deploy/phpfpm.test.nix` covering `cgi-fcgi` ping to `/ping`, and verify it returns `pong`.
- [ ] 6.11 Add `_tests/deploy/wiring-ports.test.nix` asserting OCI ExposedPorts + runner `--publish` + `nft` accept rule + end-to-end host->VM HTTP request, and verify all four destinations receive the value.
- [ ] 6.12 Add `_tests/deploy/wiring-env.test.nix` asserting OCI Env + runner `--env` + `/proc/<pid>/environ` in daemon mode, and verify all three destinations show the value.
- [ ] 6.13 Add `_tests/deploy/wiring-volumes.test.nix` asserting OCI Volumes for `declaredVolumes` and host bind visibility for `volumes`, and verify each.
- [ ] 6.14 Add `_tests/deploy/wiring-deps.test.nix` asserting the runner unit's After+Requires includes the loader by default and any extra `dependencies`, and verify via `systemctl show`.

## 7. Build-invariant tests (spec: testing/build-invariant-verification)

- [ ] 7.1 Add `_tests/invariant/reproducibility.test.nix` per design D6 (two `nix build` invocations, compare manifest digests via `nix path-info --json`), and verify identical digests on the fixture container.
- [ ] 7.2 Add `_tests/invariant/coherence-p2.test.nix` (NET_RAW under seccomp arg filters), and verify `tryEval` fails with a P2-tagged error.
- [ ] 7.3 Add `_tests/invariant/coherence-p3.test.nix` (phantom capabilities), and verify tryEval fails with a P3-tagged error.
- [ ] 7.4 Add `_tests/invariant/coherence-p5.test.nix` (AppArmor rules dead under seccomp network block), and verify tryEval fails with P5.
- [ ] 7.5 Add `_tests/invariant/coherence-p6.test.nix` (AppArmor deny contradicts SYS_ADMIN), and verify tryEval fails with P6.
- [ ] 7.6 Add `_tests/invariant/coherence-c1.test.nix` (privileged port without NET_BIND_SERVICE), and verify tryEval fails with C1.
- [ ] 7.7 Add `_tests/invariant/coherence-c2.test.nix` (custom seccomp JSON opacity), and verify tryEval fails with C2.
- [ ] 7.8 Add `_tests/invariant/coherence-c3.test.nix` (custom AppArmor opacity), and verify tryEval fails with C3.
- [ ] 7.9 Add `_tests/invariant/coherence-s1.test.nix` (strict + web-server), and verify tryEval fails with S1.
- [ ] 7.10 Add `_tests/invariant/coherence-s2.test.nix` (strict + database), and verify tryEval fails with S2.
- [ ] 7.11 Add `_tests/invariant/coherence-s4.test.nix` (strict + noNewPrivileges=false), and verify tryEval fails with S4.
- [ ] 7.12 Add `_tests/invariant/coherence-warnings.test.nix` covering D2, D3, D4, D5, D6, G3 (build succeeds but a trace/warning line is emitted), and verify each warning appears in the build log for the matching contradiction.
- [ ] 7.13 Add `_tests/invariant/coherence-nofalse.test.nix` with a satisfying configuration, and verify no P2..S4 assertion fires.
- [ ] 7.14 Add `_tests/invariant/label-network.test.nix` covering tcp-ports and udp-ports labels, and verify each label matches the declared ports.
- [ ] 7.15 Add `_tests/invariant/label-kubernetes.test.nix` covering PSS `restricted`, run-as-user, run-as-group, fs-group, seccomp-profile-type presence/absence conditions, and verify each rule.
- [ ] 7.16 Add `_tests/invariant/label-runtime.test.nix` covering runtime.user and runtime.is-root for isRoot true and false, and verify each.
- [ ] 7.17 Add `_tests/invariant/label-nix.test.nix` covering pname, version, main-program, dependency-count, and verify each reflects `pkgs.hello` + declared dependencies.
- [ ] 7.18 Add `_tests/invariant/label-performance.test.nix` covering allocator, turbo, turbo-soci label presence when enabled and absence when disabled, and verify each.
- [ ] 7.19 Add `_tests/invariant/label-security.test.nix` covering known-vulnerabilities + insecure + provenance labels for a vulnerable-flagged package and a clean package, and verify each.
- [ ] 7.20 Add `_tests/invariant/label-oci-annotations.test.nix` covering description, licenses, url, authors, documentation, base.name from a package meta fixture, and verify each annotation matches meta.

## 8. Multi-arch tests (spec: testing/multi-arch-verification, opt-in)

- [ ] 8.1 Add `_tests/multi-arch/merge.test.nix` covering `mkMergeMultiArchApp` output shape and temp-tag cleanup, and verify the resulting index contains both arch manifests and temp tags are removed after merge.
- [ ] 8.2 Add `_tests/multi-arch/cross-compile.test.nix` building an aarch64 container from x86_64 via `multiArch.crossBuild.enable = true`, and verify the resulting manifest reports `architecture = "arm64"`.
- [ ] 8.3 Add `_tests/multi-arch/emulated.test.nix` covering the multi-system emulated path for two architectures, and verify per-arch outputs exist with matching manifest architectures.
- [ ] 8.4 Wire `checks.<sys>.multi-arch` as a top-level check that's NOT included in the default `nix flake check` set (per design D8), and verify `nix flake check` doesn't build it but `nix build .#checks.<sys>.multi-arch` does.
- [ ] 8.5 Add a `workflow_dispatch` job in `.github/workflows/ci.yml` gated by a `multi-arch: true` input that invokes the check from 8.4, and verify the job triggers manually and doesn't run on push/PR.

## 9. Docs and integration

- [ ] 9.1 Extend `docs/content/test-reference/nix-lib-testing.md` and `docs/content/test-reference/testing-flake-parts-options.md` to document each new assertion helper from 1.1, and verify the pages build without lint errors.
- [ ] 9.2 Add "Verified by" backlinks in `docs/content/security/hardening.md` for each hardening feature -> corresponding runtime test file, and verify each link resolves.
- [ ] 9.3 Add "Verified by" backlinks in `docs/content/security/container-probes.md` for each probe -> its e2e test scenario, and verify each link resolves.
- [ ] 9.4 Add "Verified by" backlinks in `docs/content/architecture/validation-gated-delivery.md` for each pipeline tool -> its behavior test, and verify each link resolves.
- [ ] 9.5 Measure `nix flake check` wall time before and after, record the delta in a comment at the top of `Taskfile.yaml` under `test:check`, and verify the delta stays under the design's 15-minute budget (per open question 1).
- [ ] 9.6 After all above land, close root bead `docs-ci-deploy-2pj` and synthesis bead `docs-ci-deploy-0cb` with a `bd note` linking to the merged PR, and verify `bd list --state open` no longer shows either.

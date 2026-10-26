## 1. Enum extension

- [ ] 1.1 Extend the `ociRuntime` enum in `nix/modules/deploy/nix-oci/options/_containers/_performance/runtime-selection.nix` with `"runsc"` and `"kata-runtime"`; verify enum accepts new values via `nix eval`

## 2. Binary resolution

- [ ] 2.1 Add an internal option resolving `ociRuntime` to a concrete binary path (`pkgs.crun`, `pkgs.runc`, `pkgs.youki`, `${pkgs.gvisor}/bin/runsc`, `${pkgs.kata-containers}/bin/kata-runtime`); verify each value resolves to an existing store path

## 3. Emitter wiring

- [ ] 3.1 Extend `nix/modules/deploy/nix-oci/nixos/run-services.nix` to emit `--runtime=<resolved-path>` in the `podman run` invocation and `Runtime=<name>` in the Quadlet `[Container]` block; verify emitted unit for each runtime value
- [ ] 3.2 Extend `nix/modules/deploy/nix-oci/home-manager/run-services.nix` similarly, gated on runtime supporting rootless (assert on `kata-runtime`); verify emitted user Quadlet

## 4. Assertions

- [ ] 4.1 Add rootless-compatibility assertion (kata-runtime not supported in rootless); verify assertion fires on synthetic home-manager config
- [ ] 4.2 Add host-binary presence assertion at deploy-eval time; verify graceful failure when the resolved path is not on PATH

## 5. BDD tests

- [ ] 5.1 Add `nix/modules/oci/containers/_tests/runtime/crun.test.nix`, `runc.test.nix`, `youki.test.nix`, `runsc.test.nix`, `kata-runtime.test.nix` covering: emitted flag matches, container starts under the selected runtime; verify all pass in VM harness (kata-runtime BDD may require a nested-KVM VM; document requirement)

## 6. Documentation

- [ ] 6.1 Write `docs/content/reference/oci-runtimes.md` with a trade-off matrix (perf, isolation class, rootless support, GPU access, licensing); verify by rendering the docs site locally

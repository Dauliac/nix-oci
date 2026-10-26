## Purpose

Complete the wiring for OCI runtime selection so the declared `ociRuntime` option value actually reaches podman and the emitted Quadlet, extended to cover `runsc` (gVisor) and `kata-runtime` as defence-in-depth options.

## ADDED Requirements

### Requirement: Runtime enum coverage

The system SHALL support `"crun" | "runc" | "youki" | "runsc" | "kata-runtime"` as values of the `ociRuntime` option.

#### Scenario: Each runtime value emits the correct binary
- **WHEN** `ociRuntime = "runsc"`
- **THEN** the emitted `podman run` invocation includes `--runtime=${pkgs.gvisor}/bin/runsc` and the Quadlet `[Container]` block contains `Runtime=runsc`.

### Requirement: Uniform emission across NixOS and home-manager

Both `nixos/run-services.nix` and `home-manager/run-services.nix` emitters SHALL respect the option and emit the resolved binary path and Quadlet key consistently.

#### Scenario: NixOS emitter honours the option
- **WHEN** a NixOS service is emitted with `ociRuntime = "youki"`
- **THEN** the emitted unit contains `--runtime=${pkgs.youki}/bin/youki` and the Quadlet contains `Runtime=youki`.

### Requirement: Rootless compatibility guard

The system SHALL assert at eval time when the selected runtime does not support rootless operation and the container is emitted in rootless context.

#### Scenario: kata-runtime in home-manager fails cleanly
- **WHEN** `ociRuntime = "kata-runtime"` on a home-manager rootless emitter
- **THEN** the build fails at eval time with a message stating kata-runtime is not supported in rootless mode.

### Requirement: Host binary presence assertion

The system SHALL assert at deploy-eval time (where the assertion is feasible) that the resolved runtime binary is present on the deploy host's PATH.

#### Scenario: Missing runtime binary fails cleanly
- **WHEN** the resolved binary path is not on PATH at deploy-eval time
- **THEN** the build fails with a message naming the runtime and pointing to the doc that lists nixpkgs derivations.

### Requirement: Default unchanged

The default value of `ociRuntime` SHALL remain `"crun"` so pre-change configurations are unaffected.

#### Scenario: Existing config unchanged
- **WHEN** a container is emitted with no explicit `ociRuntime` value
- **THEN** the emitted invocation does not include `--runtime=` and podman falls back to its own default (crun).

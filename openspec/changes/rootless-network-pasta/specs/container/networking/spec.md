## Purpose

Select the rootless-container network backend explicitly (pasta by default, slirp4netns retained), so rootless quadlets emitted by home-manager and NixOS uid-mapped services capture the podman 5.0+ perf and syscall-surface improvements without relying on host defaults.

## ADDED Requirements

### Requirement: Rootless backend selection

The system SHALL expose a per-container option `oci.container.network.rootlessBackend` with enum `"pasta" | "slirp4netns"` and default `"pasta"`.

#### Scenario: Default backend is pasta
- **WHEN** a container is emitted without an explicit backend option
- **THEN** the emitted `podman run` invocation includes `--network=pasta` and the Quadlet `Network=pasta` key is present.

#### Scenario: Legacy backend still selectable
- **WHEN** `rootlessBackend = "slirp4netns"`
- **THEN** the emitted invocation and Quadlet select slirp4netns instead.

### Requirement: Host podman version guard

The system SHALL assert at deploy-eval time that the host `podman` version is >= 5.0 when `pasta` is selected, and MUST print an actionable message when the version is older.

#### Scenario: Older podman fails cleanly
- **WHEN** the target has podman < 5.0 and pasta is selected
- **THEN** the build fails at eval time with a message naming the host version and the required minimum.

### Requirement: Uniform emission across NixOS and home-manager

The emitters in `nixos/run-services.nix` and `home-manager/run-services.nix` SHALL both honour the option; NixOS emitter applies it only to uid-mapped services (root-owned containers keep host networking).

#### Scenario: Home-manager quadlet uses pasta
- **WHEN** a home-manager user emits a container
- **THEN** the emitted Quadlet has `Network=pasta` in its `[Container]` block.

#### Scenario: NixOS root-owned container is unaffected
- **WHEN** a NixOS service runs root-owned
- **THEN** the emitted unit does not add `--network=pasta` and continues using host networking.

### Requirement: Behavior parity

Container-facing network behavior SHALL be identical under both backends (NAT + port forwarding); only throughput and syscall surface differ.

#### Scenario: Port forwarding works under both backends
- **WHEN** a container publishes port 8080 under either backend
- **THEN** connections to `localhost:8080` on the host reach the container's port 8080.

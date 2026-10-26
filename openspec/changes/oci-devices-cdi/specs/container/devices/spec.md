## Purpose

Declare container device requirements via CDI (Container Device Interface) references, emitted uniformly to podman CLI and Quadlet `AddDevice=`, so image and deploy config express a standards-track device contract that applies uniformly to GPU, FPGA, TPM, and USB devices.

## ADDED Requirements

### Requirement: CDI device declaration

The system SHALL expose a per-container option `oci.container.devices.cdi` accepting a list of CDI device reference strings of the form `<vendor>/<class>=<device>`.

#### Scenario: NVIDIA GPU device declared
- **WHEN** `devices.cdi = [ "nvidia.com/gpu=all" ]`
- **THEN** the emitted `podman run` invocation includes `--device nvidia.com/gpu=all` and the emitted Quadlet contains `AddDevice=nvidia.com/gpu=all` in the `[Container]` block.

### Requirement: Uniform emitter for podman and Quadlet

The emitters SHALL produce equivalent CDI declarations in both the imperative `podman run` command and the declarative Quadlet, so the deploy artifact matches the ad-hoc run path.

#### Scenario: Declarations match across emitters
- **WHEN** a container is deployed via NixOS Quadlet and also runnable via `podman run`
- **THEN** both paths declare the same list of CDI devices in the same order.

### Requirement: Legacy NVIDIA env-var path deprecation

The existing `oci.container.gpu.*` env-var-based NVIDIA path SHALL continue to work for backwards compatibility, but SHALL be marked deprecated in the documentation with a migration example to the CDI path.

#### Scenario: Legacy config still works
- **WHEN** a project uses the legacy `oci.container.gpu.enable = true` path
- **THEN** the container starts identically to the pre-change behavior.

#### Scenario: Deprecation is discoverable
- **WHEN** a reader consults `docs/content/reference/container-devices.md`
- **THEN** the doc contains a section titled "Migrating from legacy NVIDIA env-var" with a before/after example.

### Requirement: Host CDI spec is a runtime dependency

The system SHALL NOT enforce that the target host has the requested CDI spec file present at build time; the requirement is that the spec is present at container-run time.

#### Scenario: Missing host spec is a runtime error
- **WHEN** the container is built with `devices.cdi = [ "nvidia.com/gpu=all" ]` and deployed to a host without `/etc/cdi/nvidia.com-gpu.json`
- **THEN** the build succeeds; the container start fails with a podman error identifying the missing CDI spec.

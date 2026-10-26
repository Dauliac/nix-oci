## Why

The current GPU wiring (`nix/modules/oci/containers/_options/gpu/enable.nix`) documents that the runtime side "uses legacy (env-var) and CDI" but no emitter actually generates a CDI (Container Device Interface) reference. CDI is the CNCF standard replacing runtime-specific device hooks (notably the NVIDIA container-toolkit hook) with a declarative JSON/YAML device spec discoverable at `/etc/cdi/*.json`. It became the default in Docker 28.2, is the default in CRI-O, and is supported by podman since 4.1 (pinned `podman 5.7` clears this comfortably). CDI applies uniformly to GPU, FPGA, TPM, and USB devices, and cleanly separates image-declared *requirements* from host-declared *availability*.

## What Changes

- Add per-container option file `nix/modules/oci/containers/_options/devices/cdi.nix` (list of CDI device references, e.g. `[ "nvidia.com/gpu=all" "intel.com/npu=all" ]`).
- Extend the podman emitter (`nix/modules/oci/podman/lib.nix` if present, otherwise `nix/modules/deploy/nix-oci/{nixos,home-manager}/run-services.nix`) to emit `--device <cdi-ref>` per entry and Quadlet `AddDevice=<cdi-ref>` in the `[Container]` block.
- Add a fixture at `nix/modules/oci/testing/fixtures/cdi-fake.json` describing a synthetic device (e.g., `example.com/widget=all`) so BDD tests can exercise the emitter without real hardware.
- BDD test `nix/modules/oci/containers/_tests/devices/cdi.test.nix` verifying (a) the flag appears with the correct value, (b) the Quadlet key is present, (c) with the fake CDI spec on the test VM's `/etc/cdi/`, the container starts and the fake device (or file marker) is present.
- Deprecate the legacy nvidia env-var path in `gpu/enable.nix` (retain it, mark as legacy in doc; do not delete until users migrate).
- Docs: new `docs/content/reference/container-devices.md` covering CDI syntax, availability requirements, and the GPU migration path.

## Capabilities

### New Capabilities
- `container/devices`: CDI-based declaration of container device requirements, emitted uniformly to podman CLI and Quadlet `AddDevice=`.

### Modified Capabilities
None.

## Impact

- No new runtime dependency (podman 5.7 pinned).
- Non-breaking: legacy `oci.container.gpu.*` env-var path continues to work; the new `oci.container.devices.cdi` is additive.
- Deploy target must have the requested CDI spec (`/etc/cdi/<vendor>-<device>.json`) present at container-run time. Documented; asserted at deploy-eval-time is out of scope (spec presence is a host runtime property).
- Enables the FPGA/TPM/USB device stories the current GPU path cannot express.

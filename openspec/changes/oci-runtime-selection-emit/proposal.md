## Why

`nix/modules/deploy/nix-oci/options/_containers/_performance/runtime-selection.nix` already declares an `ociRuntime` enum with `crun | runc | youki`. The declaration is a stub: no emitter under `nix/modules/deploy/nix-oci/{nixos,home-manager}/run-services.nix` maps the enum to a `--runtime=<bin>` flag on `podman run` or a Quadlet `[Container]` `Runtime=<name>` key. The plumbing is 90% scaffolded; finishing it is the cheapest Section-2 win in the exploration roadmap. Additionally the enum should grow `runsc` (gVisor, VM-class isolation without a VM) and `kata-runtime` (hardware-isolated containers) because both are packaged (`pkgs.gvisor 20250512.0`, kata via nixpkgs' virtualisation set).

## What Changes

- Extend the `ociRuntime` enum in `nix/modules/deploy/nix-oci/options/_containers/_performance/runtime-selection.nix` with `"runsc"` and `"kata-runtime"`.
- Add an internal option resolving `ociRuntime` to a concrete binary path (`pkgs.crun`, `pkgs.runc`, `pkgs.youki`, `${pkgs.gvisor}/bin/runsc`, `${pkgs.kata-containers}/bin/kata-runtime`).
- Extend `nix/modules/deploy/nix-oci/nixos/run-services.nix` to emit `--runtime=<resolved-path>` in the `podman run` invocation and `Runtime=<name>` in the Quadlet `[Container]` block.
- Do the same for `nix/modules/deploy/nix-oci/home-manager/run-services.nix` (rootless), gated on runtime supporting rootless (crun/runc/youki yes; runsc has partial support; kata-runtime no - assert).
- BDD tests under `nix/modules/oci/containers/_tests/runtime/`:
  - one per runtime: emitted flag matches, container starts, a probe (e.g., `uname -r` inside container vs host) confirms the runtime is actually used.
- Doc: new `docs/content/reference/oci-runtimes.md` with a trade-off matrix (perf, isolation class, rootless support, GPU access, licensing).
- Deprecation note: none. All existing configs default to `crun` (current default); behavior unchanged unless the option is set.

## Capabilities

### New Capabilities
- `container/oci-runtime`: OCI runtime selection (crun, runc, youki, runsc, kata-runtime), emitted uniformly to podman CLI and Quadlet.

### Modified Capabilities
None (the existing option was declaration-only, not spec'd).

## Impact

- No new runtime dependency in the image; runtime binaries live on the deploy host.
- Deploy-side dependency: whichever runtime is selected must be present on the host; assertion checks the binary path exists at deploy-eval-time when possible.
- Composes with `quadlet-systemd-hardening-modern` (Runtime= sits next to the new hardening directives).
- Enables gVisor and Kata defence-in-depth stories that nix-oci currently cannot express.

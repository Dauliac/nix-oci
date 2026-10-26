## Why

The Quadlets and NixOS units emitted from `nix/modules/deploy/nix-oci/{nixos,home-manager}/run-services.nix` set the classic hardening triad (`NoNewPrivileges`, `PrivateTmp`, `ProtectSystem`) but do not use the newer systemd directives available since systemd 250 (2022) and now widely deployed: `RestrictNetworkInterfaces=`, `ProtectHostname=`, `RestrictFileSystems=`, and `ProtectProc=invisible`. NixOS pins `systemd 258.7` today, so every directive is available; distros running RHEL 9.4+, Fedora 36+, Debian 12+ (with backport) also clear the bar. These are free defence-in-depth wins the emitted units currently leave on the table.

## What Changes

- Add per-container option tree `nix/modules/oci/containers/_options/hardening/systemd/`:
  - `restrict-network-interfaces.nix` (list of interface names to whitelist)
  - `protect-hostname.nix` (bool, default false pending compat matrix; opt-in)
  - `restrict-filesystems.nix` (list of fstype groups like `@network`, `@nfs`)
  - `protect-proc.nix` (enum `"default" | "invisible" | "noaccess" | "ptraceable"`, default `"invisible"`)
- Extend Quadlet emission in `nix/modules/deploy/nix-oci/nixos/run-services.nix` (root) and `home-manager/run-services.nix` (rootless) to fold each option into the `[Service]` section (respecting rootless: some directives are silently ignored under user-mode systemd, documented).
- Assertion in `nix/modules/deploy/nix-oci/nixos/_config/assertions.nix` that host `systemd` version is >= 250 when any of the new directives is enabled; friendly failure message otherwise.
- BDD tests under `nix/modules/oci/containers/_tests/hardening/systemd/` per directive: (a) directive appears in emitted unit, (b) unit still starts, (c) directive actually restricts (e.g., `RestrictNetworkInterfaces=lo` blocks external traffic to the container).
- Docs: extend `docs/content/security/hardening.md` with a "systemd unit hardening" subsection.

## Capabilities

### New Capabilities
- `deploy/quadlet-hardening`: extended systemd unit hardening directives (systemd >= 250) folded into emitted Quadlets and NixOS units.

### Modified Capabilities
None (existing hardening options were never separately spec'd).

## Impact

- No new runtime dependencies; systemd 258.7 pinned in NixOS default.
- Backwards-compatible: every directive defaults off (except `ProtectProc = "invisible"` which is a safe default even for older systemd via the fallback semantics).
- Rootless behavior differs from root (user-mode systemd ignores several directives silently); documented in the how-to.
- Composes with future `oci-runtime-selection-emit` (Runtime= key) and `rootless-network-pasta` (network backend).

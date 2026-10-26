## Why

Rootless podman quadlets emitted from `nix/modules/deploy/nix-oci/home-manager/run-services.nix` do not currently express a network backend, falling through to whatever the host podman default happens to be. Since podman 5.0 (2024), `pasta` (from the passt project) is the default rootless network backend, replacing `slirp4netns`. The switch is worth an explicit toggle for two reasons: (a) pasta is 4-50x faster than slirp4netns on IPv4 TCP throughput, (b) pasta is seccomp-locked to 43 syscalls on x86_64 with all caps dropped except optional `CAP_NET_BIND_SERVICE`, a materially smaller attack surface. Both `passt 2025_09_19` and `podman 5.7` are in the pinned nixpkgs.

## What Changes

- Add per-container option file `nix/modules/oci/containers/_options/network/rootless-backend.nix` with enum `"pasta" | "slirp4netns"`, default `"pasta"`.
- Extend rootless emission in `nix/modules/deploy/nix-oci/home-manager/run-services.nix` to append `--network=<backend>` (or set the equivalent Quadlet `Network=<backend>` key when podman 5.0+ Quadlet syntax supports it).
- Extend the root NixOS emitter (`nix/modules/deploy/nix-oci/nixos/run-services.nix`) with the same option for consistency (uid-mapped services benefit from pasta too; root-owned containers keep default host networking).
- Assertion that host podman version is >= 5.0 when `pasta` selected; helpful failure message with the version-bump remediation.
- BDD test `nix/modules/oci/containers/_tests/network/rootless-backend.test.nix` verifying (a) `pasta` selected -> `--network=pasta` in emitted command, (b) `slirp4netns` selected -> corresponding flag, (c) a rootless container pings out under both backends.
- Doc: extend `docs/content/how-to/nixos-containers.md` (or a new `how-to/rootless-networking.md`) with the trade-off table.

## Capabilities

### New Capabilities
- `container/networking`: rootless-container network backend selection with pasta as the default, encoding the perf/syscall-surface trade-off vs slirp4netns explicitly.

### Modified Capabilities
None.

## Impact

- No new runtime dependency; passt and podman 5.7 both in the pinned nixpkgs.
- Non-breaking on hosts running podman 5.0+; the assertion catches older-host regressions cleanly.
- Composes with `quadlet-systemd-hardening-modern` (specifically `RestrictNetworkInterfaces=`).
- Container-facing behavior identical (both backends provide NAT + port forwarding); throughput and syscall surface change.

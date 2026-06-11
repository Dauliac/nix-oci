# oci.snapshotter -- host-level lazy-pulling configuration.
#
# Wraps the shared _snapshotter option definitions into an
# oci.snapshotter submodule and registers it for NixOS and
# system-manager (not home-manager — snapshotters are system daemons).
{ ... }:
let
  snapshotterModules = import ./_snapshotter;

  mod =
    { lib, ... }:
    {
      options.oci.snapshotter = lib.mkOption {
        type = lib.types.submoduleWith {
          modules = snapshotterModules;
        };
        default = { };
        description = ''
          Host-level lazy-pulling snapshotter configuration.

          Configures the container runtime (containerd or Podman) to
          support lazy image pulls using SOCI, eStargz, or zstd:chunked.

          This is the deploy-side counterpart to the build-side
          `performance.turbo` options: turbo produces the indexes/layers,
          and the snapshotter consumes them at pull time.

          - **soci** / **stargz**: containerd proxy snapshotters (docker backend)
          - **zstdChunked**: native Podman/CRI-O feature (podman backend)
        '';
      };
    };
in
{
  flake.modules.nixos.nix-oci-snapshotter = mod;
  flake.modules.systemManager.nix-oci-snapshotter = mod;
}

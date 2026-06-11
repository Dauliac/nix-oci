# Inner NixOS eval: capability options forwarded from flake-parts.
#
# These are runtime hints (deploy modules translate to --cap-drop/--cap-add)
# but the NixOS eval needs them for cross-backend coherence assertions
# in coherence.nix (e.g. seccomp blocks what a capability would allow).
{ lib, ... }:
{
  options.oci.container.hardening.capabilities = lib.mkOption {
    type = lib.types.submodule {
      options = {
        drop = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "ALL" ];
          description = "Linux capabilities to drop.";
        };
        add = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Linux capabilities to add back after dropping.";
        };
      };
    };
    default = { };
    description = "Linux capability restrictions (forwarded for coherence checks).";
  };
}

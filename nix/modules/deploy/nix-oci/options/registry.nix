# oci.registry -- local registry configuration for push-based loading.
#
# When enabled with a containerd backend, images are pushed to the
# local registry via copyToRegistry instead of direct loading.
# This enables SOCI lazy pulling and layer dedup.
{ ... }:
let
  mod =
    { lib, ... }:
    {
      options.oci.registry = {
        enable = lib.mkEnableOption "push-based image loading via local registry";

        host = lib.mkOption {
          type = lib.types.str;
          default = "localhost";
          description = "Hostname of the local OCI registry.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 5000;
          description = "Port of the local OCI registry.";
        };
      };
    };
in
{
  flake.modules.nixos.nix-oci-registry = mod;
  flake.modules.systemManager.nix-oci-registry = mod;
}

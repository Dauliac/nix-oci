# Compose the final nix-oci modules for each platform using flake.modules (typed API).
#
# Each leaf module (options/*, nixos/*, home-manager/*) registers itself as
# `flake.modules.{nixos,homeManager}.nix-oci-<name>`. This module composes
# them into the final `nix-oci` module per platform.
#
# Consumers import via:
#   inputs.nix-oci.modules.nixos.nix-oci
#   inputs.nix-oci.modules.homeManager.nix-oci
{ config, ... }:
let
  nixosMods = config.flake.modules.nixos;
  hmMods = config.flake.modules.homeManager;
in
{
  flake.modules.nixos.nix-oci =
    { ... }:
    {
      imports = [
        nixosMods.nix-oci-enable
        nixosMods.nix-oci-backend
        nixosMods.nix-oci-containers
        nixosMods.nix-oci-lib
        nixosMods.nix-oci-load-services
        nixosMods.nix-oci-oci-containers
      ];
    };

  flake.modules.homeManager.nix-oci =
    { ... }:
    {
      imports = [
        hmMods.nix-oci-enable
        hmMods.nix-oci-backend
        hmMods.nix-oci-containers
        hmMods.nix-oci-lib
        hmMods.nix-oci-load-services
        hmMods.nix-oci-podman-containers
      ];
    };
}

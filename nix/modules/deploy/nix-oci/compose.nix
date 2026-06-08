# Compose the final nix-oci modules for each platform.
#
# Injects nix2container (from flake inputs) into the NixOS/HM/SM modules
# so that _containers/image.nix can build images.
{ config, inputs, ... }:
let
  nixosMods = config.flake.modules.nixos;
  hmMods = config.flake.modules.homeManager;
  smMods = config.flake.modules.systemManager;
in
{
  flake.modules.nixos.nix-oci =
    { pkgs, ... }:
    {
      imports = [
        nixosMods.nix-oci-enable
        nixosMods.nix-oci-backend
        nixosMods.nix-oci-containers
        nixosMods.nix-oci-load-services
        nixosMods.nix-oci-run-services
      ];
      _module.args.nix2container =
        inputs.nix2container.packages.${pkgs.system}.nix2container;
    };

  flake.modules.homeManager.nix-oci =
    { pkgs, ... }:
    {
      imports = [
        hmMods.nix-oci-enable
        hmMods.nix-oci-backend
        hmMods.nix-oci-containers
        hmMods.nix-oci-load-services
        hmMods.nix-oci-run-services
      ];
      _module.args.nix2container =
        inputs.nix2container.packages.${pkgs.system}.nix2container;
    };

  flake.modules.systemManager.nix-oci =
    { pkgs, ... }:
    {
      imports = [
        smMods.nix-oci-enable
        smMods.nix-oci-backend
        smMods.nix-oci-containers
        smMods.nix-oci-load-services
      ];
      _module.args.nix2container =
        inputs.nix2container.packages.${pkgs.system}.nix2container;
    };
}

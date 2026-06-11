# Compose the final nix-oci modules for each platform.
#
# Injects nix2container (from flake inputs) into the NixOS/HM/SM modules
# so that _containers/image.nix can build images.
# Also exports the NixOS container eval module tree (_nixos-oci) as a
# public module for reuse by other projects.
{
  config,
  inputs,
  ...
}:
let
  import-tree = inputs.import-tree;
  nixosMods = config.flake.modules.nixos;
  hmMods = config.flake.modules.homeManager;
  smMods = config.flake.modules.systemManager;
in
{
  # Export the NixOS container eval module tree.
  # Internal path uses _ prefix (excluded from flake-parts import-tree),
  # but exported as a public module for consumers and nix-lib collection.
  flake.modules.nixos-oci = import-tree ../../../_nixos-oci;

  flake.modules.nixos.nix-oci =
    { pkgs, ... }:
    {
      imports = [
        nixosMods.nix-oci-enable
        nixosMods.nix-oci-backend
        nixosMods.nix-oci-snapshotter
        nixosMods.nix-oci-containers
        nixosMods.nix-oci-load-services
        nixosMods.nix-oci-run-services
        nixosMods.nix-oci-snapshotter-config
      ];
      _module.args.nix2container = inputs.nix2container.packages.${pkgs.system}.nix2container;
      _module.args.nixLibNixosModule = inputs.nix-lib.nixosModules.default;
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
      _module.args.nix2container = inputs.nix2container.packages.${pkgs.system}.nix2container;
      _module.args.nixLibNixosModule = inputs.nix-lib.nixosModules.default;
    };

  flake.modules.systemManager.nix-oci =
    { pkgs, ... }:
    {
      imports = [
        smMods.nix-oci-enable
        smMods.nix-oci-backend
        smMods.nix-oci-snapshotter
        smMods.nix-oci-containers
        smMods.nix-oci-load-services
        smMods.nix-oci-run-services
        smMods.nix-oci-snapshotter-config
      ];
      _module.args.nix2container = inputs.nix2container.packages.${pkgs.system}.nix2container;
      _module.args.nixLibNixosModule = inputs.nix-lib.nixosModules.default;
    };
}

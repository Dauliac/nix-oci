# Compose the final nix-oci modules for each platform.
#
# Injects nix2container (from flake inputs) into the NixOS/HM/SM modules
# so that _containers/image.nix can build images.
# Also exports the NixOS container eval module tree (_nixos-oci) as a
# public module for reuse by other projects.
{
  config,
  inputs,
  lib,
  ...
}:
let
  discoverModules = import ../../../lib/discoverModules.nix { inherit lib; };
  nixosMods = config.flake.modules.nixos;
  hmMods = config.flake.modules.homeManager;
  smMods = config.flake.modules.systemManager;
in
{
  # Export the NixOS container eval module tree.
  # Internal path uses _ prefix (excluded from flake-parts import-tree),
  # but exported as a public module for consumers and nix-lib collection.
  flake.modules.nixos-oci = {
    imports = discoverModules ../../../_nixos-oci;
  };

  flake.modules.nixos.nix-oci =
    { pkgs, ... }:
    {
      imports = [
        nixosMods.nix-oci-enable
        nixosMods.nix-oci-backend
        nixosMods.nix-oci-registry
        nixosMods.nix-oci-snapshotter
        nixosMods.nix-oci-containers
        nixosMods.nix-oci-load-services
        nixosMods.nix-oci-run-services
        nixosMods.nix-oci-snapshotter-config
        nixosMods.soci-snapshotter
      ];
      _module.args.nix2container = inputs.nix2container.packages.${pkgs.system}.nix2container;
      _module.args.nixLibNixosModule = inputs.nix-lib.nixosModules.default;
      # nix2container's own skopeo fork, patched to understand the
      # custom "nix:" source transport that copyToRegistry's push
      # scripts always use as their source ref -- plain nixpkgs skopeo
      # does not implement this transport at all ("unknown transport
      # nix", reproduced live). Same package perSystem's
      # oci.packages.skopeo defaults to (nix/modules/oci/packages/
      # skopeo.nix); duplicated here via _module.args rather than
      # routed through config.oci.packages because NixOS modules can't
      # reach perSystem options, same reasoning as skopeoTurbo below.
      _module.args.skopeoNix2Container =
        inputs.nix2container.packages.${pkgs.system}.skopeo-nix2container;
      # Same null-when-unavailable fallback as perSystem's
      # oci.packages.skopeoTurbo -- see nix/modules/oci/packages/skopeoTurbo.nix.
      # Load-services.nix needs this directly: NixOS modules can't reach
      # perSystem options, so this mirrors the nix2container injection
      # above rather than routing through config.oci.packages.
      _module.args.skopeoTurbo =
        if inputs ? nix2container-turbo then
          inputs.nix2container-turbo.packages.${pkgs.system}.skopeo
        else
          null;
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
        hmMods.soci-snapshotter
      ];
      _module.args.nix2container = inputs.nix2container.packages.${pkgs.system}.nix2container;
      _module.args.nixLibNixosModule = inputs.nix-lib.nixosModules.default;
      _module.args.skopeoNix2Container =
        inputs.nix2container.packages.${pkgs.system}.skopeo-nix2container;
    };

  flake.modules.systemManager.nix-oci =
    { pkgs, ... }:
    {
      imports = [
        smMods.nix-oci-enable
        smMods.nix-oci-backend
        smMods.nix-oci-registry
        smMods.nix-oci-snapshotter
        smMods.nix-oci-containers
        smMods.nix-oci-load-services
        smMods.nix-oci-run-services
        smMods.nix-oci-snapshotter-config
        smMods.soci-snapshotter
      ];
      _module.args.nix2container = inputs.nix2container.packages.${pkgs.system}.nix2container;
      _module.args.nixLibNixosModule = inputs.nix-lib.nixosModules.default;
      _module.args.skopeoNix2Container =
        inputs.nix2container.packages.${pkgs.system}.skopeo-nix2container;
    };
}

args@{ flake-parts-lib, ... }:
{
  imports = [
    (flake-parts-lib.importApply ./modules args)
  ];
  config = {
    flake.modules.flake.default = ./modules/default.nix;
    flake.modules.flake.nix-oci = ./modules/default.nix;
    flake.flakeModules.nix-oci = ./modules/default.nix;
    flake.flakeModules.default = ./modules/default.nix;
    flake.flakeModule = ./modules/default.nix;
  };
}

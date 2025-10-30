args@{
  flake-parts-lib,
  inputs,
  ...
}:
{
  imports = [
    (flake-parts-lib.importApply ./modules args)
  ];
  config = {
    flake.modules.flake.default = import ./modules/flake-module.nix inputs;
    flake.modules.flake.nix-oci = import ./modules/flake-module.nix inputs;
    flake.flakeModules.nix-oci = import ./modules/flake-module.nix inputs;
    flake.flakeModules.default = import ./modules/flake-module.nix inputs;
    flake.flakeModule = import ./modules/flake-module.nix inputs;
  };
}

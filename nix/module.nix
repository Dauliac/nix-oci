{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (inputs.flake-parts.lib) importApply;
  flakeModule = importApply ./modules {
    inherit inputs;
    inherit config;
    inherit lib;
  };
in
{
  imports = [
    flakeModule
  ];
  config = {
    flake.modules.flake.default = flakeModule;
    flake.modules.flake.nix-oci = flakeModule;
    flake.flakeModules.nix-oci = flakeModule;
    flake.flakeModules.default = flakeModule;
    flake.flakeModule = flakeModule;
  };
}

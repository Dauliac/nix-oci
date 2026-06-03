args@{
  flake-parts-lib,
  inputs,
  ...
}:
{
  # Modules are imported via import-tree in flake.nix
  config =
    let
      module = import ./flake-module.nix inputs;
    in
    {
      flake.modules.flake.default = module;
      flake.modules.flake.nix-oci = module;
      flake.flakeModules.nix-oci = module;
      flake.flakeModules.default = module;
      flake.flakeModule = module;
    };
}

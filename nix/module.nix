args@{
  flake-parts-lib,
  inputs,
  ...
}:
{
  # Modules are imported via import-tree in flake.nix
  config = {
    flake.modules.flake.default = import ./flake-module.nix inputs;
    flake.modules.flake.nix-oci = import ./flake-module.nix inputs;
    flake.flakeModules.nix-oci = import ./flake-module.nix inputs;
    flake.flakeModules.default = import ./flake-module.nix inputs;
    flake.flakeModule = import ./flake-module.nix inputs;
  };
}

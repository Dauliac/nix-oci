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
  };
in
{
  imports = [
    ./lib
    ./treefmt.nix
    ./examples.nix
    ./templates.nix
    inputs.flake-parts.flakeModules.modules
    flakeModule
  ];
  config = {
    oci.enabled = true;
    flake.modules.flake.default = flakeModule;
    flake.modules.flake.nix-oci = flakeModule;
    flake.flakeModules.nix-oci = flakeModule;
    flake.flakeModules.default = flakeModule;
    flake.flakeModule = flakeModule;
    perSystem =
      {
        config,
        pkgs,
        inputs',
        ...
      }:
      {
        devShells.default = pkgs.mkShell {
          packages =
            with pkgs;
            [
              cosign
              conftest
              bats
              parallel
              lefthook
              convco
            ]
            ++ config.oci.internal.packages;
          shellHook = ''
            ${pkgs.lefthook}/bin/lefthook install --force
          '';
        };
      };
  };
}

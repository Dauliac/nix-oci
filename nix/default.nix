{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (inputs.flake-parts.lib) importApply;
  flakeModules = importApply ./modules {
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
    flakeModules
  ];
  config = {
    oci.enabled = true;
    flake.modules.flake.default = flakeModules;
    flake.modules.flake.nix-oci = flakeModules;
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

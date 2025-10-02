{
  inputs,
  config,
  withSystem,
  ...
}:
let
  inherit (inputs.flake-parts.lib) importApply;
  flakeModule = importApply ./modules {
    inherit withSystem;
    inherit inputs;
    inherit config;
  };
in
{
  imports = [
    ./treefmt.nix
    ./examples.nix
    ./templates.nix
    ./module.nix
    inputs.flake-parts.flakeModules.modules
  ];
  config = {
    oci.enabled = true;
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

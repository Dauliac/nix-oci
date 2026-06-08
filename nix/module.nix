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

      mkStandaloneModule =
        path:
        {
          imports = [ (inputs.import-tree path) ];
          _module.args.import-tree = inputs.import-tree;
        };

      nixosModule = mkStandaloneModule ./standalone/nixos/nix-oci;
      homeManagerModule = mkStandaloneModule ./standalone/home-manager/nix-oci;
    in
    {
      flake.modules.flake.default = module;
      flake.modules.flake.nix-oci = module;
      flake.flakeModules.nix-oci = module;
      flake.flakeModules.default = module;
      flake.flakeModule = module;

      flake.nixosModules.nix-oci = nixosModule;
      flake.nixosModules.default = nixosModule;

      flake.homeManagerModules.nix-oci = homeManagerModule;
      flake.homeManagerModules.default = homeManagerModule;
    };
}

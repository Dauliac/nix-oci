{
  description = "Nix OCI";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
    nix-lib = {
      url = "github:Dauliac/nix-lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
  };
  outputs =
    inputs@{
      flake-parts,
      treefmt-nix,
      nix2container,
      nix-lib,
      import-tree,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (_: {
      debug = true;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [
        ./nix/treefmt.nix
        ./nix/examples.nix
        ./nix/templates.nix
        ./nix/module.nix
        inputs.flake-parts.flakeModules.modules
        inputs.nix-lib.flakeModules.default
        # Use import-tree internally for auto-discovery
        (import-tree ./nix/modules)
      ];
      oci.enabled = true;
      perSystem =
        {
          config,
          pkgs,
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
                regclient
              ]
              ++ config.oci.internal.packages;
            shellHook = ''
              ${pkgs.lefthook}/bin/lefthook install --force
            '';
          };
        };
    });
}

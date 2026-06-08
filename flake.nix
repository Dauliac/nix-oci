{
  description = "Nix OCI";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix2container = {
      url = "github:nlewo/nix2container";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
    import-tree = {
      url = "github:denful/import-tree";
    };
    nix-lib = {
      url = "github:Dauliac/nix-lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs@{
      flake-parts,
      nix2container,
      nix-lib,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [
        inputs.flake-parts.flakeModules.modules
        inputs.flake-parts.flakeModules.partitions
        ./nix/module.nix
        ./nix/templates.nix
      ];

      _module.args.import-tree = inputs.import-tree;

      # Dev-only outputs come from the dev partition
      partitionedAttrs.apps = "dev";
      partitionedAttrs.packages = "dev";
      partitionedAttrs.checks = "dev";
      partitionedAttrs.devShells = "dev";
      partitionedAttrs.formatter = "dev";

      # Doc-only outputs (isolated from consumers)
      partitionedAttrs.legacyPackages = "docs";

      partitions.docs = {
        extraInputsFlake = ./docs;
        module =
          { inputs, ... }:
          {
            imports = [
              inputs.github-actions-nix.flakeModules.default
              ./nix/docs.nix
              (import ./nix/flake-module.nix inputs)
            ];
            oci.enabled = true;
          };
      };

      partitions.dev = {
        extraInputsFlake = ./dev;
        module =
          { inputs, ... }:
          {
            imports = [
              # Load the full OCI module system (same as consumers would)
              (import ./nix/flake-module.nix inputs)
              # Build examples (CST, dgoss, etc.)
              ./nix/examples.nix
              # Treefmt formatter and check
              ./nix/treefmt.nix
              # Deploy integration test (NixOS + home-manager in one VM)
              ./nix/tests/deploy.nix
            ];
            oci.enabled = true;
            debug = true;
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
                      act
                    ]
                    ++ config.oci.internal.packages;
                  shellHook = ''
                    ${pkgs.lefthook}/bin/lefthook install --force
                  '';
                };
              };
          };
      };
    };
}

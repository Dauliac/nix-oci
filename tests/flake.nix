# Standalone BDD test flake for nix-oci.
#
# Tests both build (flake-parts) and deploy (NixOS) pipelines by
# importing example modules via nix/examples.nix (which uses import-tree
# to auto-discover all examples/flake/* modules).
#
# Container coverage:
#   - Build pipeline:  examples/flake/* (auto-discovered)
#   - Deploy pipeline: examples/deploy-nixos/* (imported into VM NixOS config)
#   - BDD specs:       _tests/*.test.nix (auto-discovered by test-collector)
#
# Adding a new example to examples/flake/ automatically adds it to tests.
#
# Run:
#   cd tests && task
#   nix build ./tests#checks.x86_64-linux.bdd-vm -L
{
  description = "nix-oci BDD test suite";

  inputs = {
    get-flake.url = "github:ursi/get-flake";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      flake-parts,
      get-flake,
      nixpkgs,
      ...
    }:
    let
      nix-oci = get-flake ../.;
      mergedInputs = nix-oci.inputs // inputs;
    in
    flake-parts.lib.mkFlake { inputs = mergedInputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        nix-oci.modules.flake.nix-oci
        nix-oci.modules.flake.nix-oci-test

        # Import ALL flake-parts examples (auto-discovered via import-tree).
        # Home-manager examples included (test flake has the input).
        (import ../nix/examples.nix {
          excludes = [
            "/multi-arch/"
            "/minimalist-with-amicontained"
            "/minimalist-with-cdk"
            "/minimalist-with-deepce"
            "/minimalist-with-linpeas"
          ];
        })
      ];

      _module.args.import-tree = nix-oci.inputs.import-tree;

      oci.enabled = true;

      perSystem =
        { pkgs, ... }:
        {
          devShells.default = pkgs.mkShell { };

          # Use nix2container-turbo for all pushes — enables cross-machine
          # layer caching via OCI Referrers API and optimized layers.
          oci.turbo.enable = true;

          # Lock files live at <project-root>/oci/, not tests/oci/
          oci.fromImageManifestRootPath = ../oci + "/";
        };
    };
}

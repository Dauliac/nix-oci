# Standalone BDD test flake for nix-oci.
#
# Imports nix-oci as a real consumer would, defines test containers,
# and verifies the full pipeline: apps, checks, VM tests.
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
      # Merge parent inputs so nix-oci modules find nix2container, import-tree, etc.
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
      ];

      _module.args.import-tree = nix-oci.inputs.import-tree;

      oci.enabled = true;

      perSystem =
        { pkgs, ... }:
        {
          devShells.default = pkgs.mkShell { };

          oci.containers.test-hello = {
            package = pkgs.hello;
            user = "nobody";
            entrypoint = [ "${pkgs.hello}/bin/hello" ];
            labels = {
              "org.opencontainers.image.title" = "test-hello";
              "org.opencontainers.image.source" = "https://github.com/Dauliac/nix-oci";
              "org.opencontainers.image.description" = "BDD test container";
            };
            policy.conftest.enabled = true;
            lint.dockle.enabled = true;
            sbom.syft.enabled = true;
            test.dive.enabled = true;
          };
        };
    };
}

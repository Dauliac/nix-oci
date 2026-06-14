# Standalone BDD test flake for nix-oci.
#
# Imports nix-oci as a real consumer would, defines test containers,
# and verifies the full pipeline: apps, checks, VM tests.
#
# Run:
#   nix flake check ./tests
#   nix build ./tests#checks.x86_64-linux.bdd-vm -L
#   nix run ./tests#oci-policy-conftest-test-hello
{
  description = "nix-oci BDD test suite";

  inputs = {
    get-flake.url = "github:ursi/get-flake";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      get-flake,
      ...
    }:
    let
      nix-oci = get-flake ../.;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        nix-oci.modules.flake.nix-oci
        nix-oci.modules.flake.nix-oci-test
      ];

      _module.args.import-tree = inputs.import-tree;

      oci.enabled = true;

      perSystem =
        { pkgs, ... }:
        {
          # Minimal devShell to avoid "no value defined" error
          devShells.default = pkgs.mkShell { };

          # ── Test container ──────────────────────────────────
          # One container with all tools enabled — generates real apps + checks.
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

# Standalone BDD test flake for nix-oci.
#
# Imports nix-oci as a real consumer would, defines test containers,
# and verifies the full pipeline: apps, checks, VM tests.
#
# Run:
#   nix flake check ./tests/bdd
#   nix build ./tests/bdd#checks.x86_64-linux.bdd-vm -L
#   nix run ./tests/bdd#oci-policy-conftest-test-hello
{
  description = "nix-oci BDD test suite";

  inputs = {
    get-flake.url = "github:ursi/get-flake";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
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
      # Import the parent nix-oci flake via get-flake
      nix-oci = get-flake ../.;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        # The real nix-oci consumer module — same as any user would import
        nix-oci.modules.flake.nix-oci
        # Test infrastructure (currently bundled in main module via import-tree)
        nix-oci.modules.flake.nix-oci-test
      ];

      # Enable OCI outputs (apps, checks, packages)
      oci.enabled = true;

      perSystem =
        {
          pkgs,
          lib,
          system,
          config,
          ...
        }:
        {
          # ── Test containers ──────────────────────────────────
          # One minimal container with all tools enabled.
          # This generates REAL apps and checks — same as a user's project.
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

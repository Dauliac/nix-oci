# Standalone BDD test flake for nix-oci.
#
# Tests both build (flake-parts) and deploy (NixOS) pipelines by
# importing example modules via nix/examples.nix (which uses import-tree
# to auto-discover all examples/flake/* modules).
#
# Container coverage:
#   - Build pipeline:  examples/flake/* (auto-discovered)
#   - Deploy pipeline: examples/deploy-nixos/* (imported into VM NixOS config)
#   - How-to docs:     examples/_how-to/*/module.nix (imported explicitly
#                      below — proves the `nix run` commands in the how-to
#                      docs resolve against a real flake output)
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

        # How-to example modules — same definitions the standalone
        # examples/_how-to/*/flake.nix files consume, imported here so a
        # change that breaks a documented `nix run .#oci-...` command
        # (e.g. a pipeline refactor that renames the app) fails
        # `nix flake check ./tests` instead of silently rotting in docs.
        # See issue #7 for the drift class this guards against.
        #
        # NixOS-side deploy modules
        # (examples/_how-to/{share-containers/nixos-server.nix,deploy-nixos/nixos-module.nix})
        # are NOT wired in here yet: `nix-oci.modules.nixos.nix-oci`
        # references `nixosMods.soci-snapshotter`, which is registered by
        # `nix/flake-module.nix` but not by `nix/module.nix`, so a pure
        # `nixpkgs.lib.nixosSystem { modules = [ nix-oci.modules.nixos.nix-oci ]; }`
        # currently fails with `attribute 'soci-snapshotter' missing`.
        # That preexisting drift affects any consumer using the NixOS
        # module without also importing the flake-parts module and needs
        # its own fix — tracked separately from this docs cleanup.
        ../examples/_how-to/flake-parts-basics/module.nix
        ../examples/_how-to/build-from-nixos-service/module.nix
        ../examples/_how-to/share-containers/module.nix
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

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
    # Home-manager release-25.05 imports helpers from
    # nixpkgs `lib/services/lib.nix` that were moved/removed in the
    # nixos-25.11 tree, so having HM follow the top-level nixpkgs
    # breaks HM evaluation with "file 'lib/services/lib.nix' not
    # found". Give HM its own matching nixpkgs (nixos-25.05) so the
    # two agree on every module API HM touches. See design D7 of
    # openspec change runtime-behavioral-test-coverage.
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    nixpkgs-home-manager.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-home-manager";
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
          # Container-probe examples (amicontained / CDK / DEEPCE / linPEAS)
          # were historically excluded because their probes cannot run in
          # a pure `nix build` sandbox. Now that test-apps.nix synthesizes
          # probe apps into the bdd-apps VM harness (bead 1.5), the four
          # `minimalist-with-<probe>` example flakes are included in
          # `nix flake check` and their probe apps execute inside the
          # bdd-apps VM which has a real podman/docker daemon.
          excludes = [
            "/multi-arch/"
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
        {
          config,
          pkgs,
          lib,
          ...
        }:
        {
          devShells.default = pkgs.mkShell { };

          # Use nix2container-turbo for all pushes — enables cross-machine
          # layer caching via OCI Referrers API and optimized layers.
          oci.turbo.enable = true;

          # Lock files live at <project-root>/oci/, not tests/oci/
          oci.fromImageManifestRootPath = ../oci + "/";

          # Expose BDD checks — internal options set by test-flake-module,
          # wired here so `nix flake check ./tests` and
          # `nix build ./tests#checks.<system>.bdd-vm` resolve.
          # Expose BDD checks. The old aggregate `bdd-apps` (a single VM
          # loading every container serially) is intentionally NOT wired
          # here: `nix flake check` cannot parallelize inside one
          # derivation, so it degraded to `boot + sum(per-container-load)`
          # ~= many hours. The per-container `bdd-app-<name>` split IS
          # wired: Nix's build scheduler runs each VM independently, so
          # wall clock becomes `boot + max(per-container-load)` and
          # `--max-jobs` bounds concurrency naturally. The aggregate
          # derivation still exists as `test.oci._bddAppsCheck` if
          # anyone actually wants the monolithic shape.
          checks =
            lib.optionalAttrs (config.test.oci._bddVmCheck != null) {
              bdd-vm = config.test.oci._bddVmCheck;
            }
            // lib.mapAttrs' (name: drv: lib.nameValuePair "bdd-app-${name}" drv) (
              config.test.oci._bddAppsChecks or { }
            );
        };
    };
}

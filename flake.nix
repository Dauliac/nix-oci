{
  description = "Nix OCI";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix2container = {
      url = "github:nlewo/nix2container";
    };
    nix2container-turbo = {
      url = "github:schlarpc/nix2container-turbo";
      inputs.nix2container.follows = "nix2container";
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
      partitionedAttrs.tests = "dev";

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
              # Full OCI library (same as consumers would import).
              (import ./nix/flake-module.nix inputs)
              # BDD test infrastructure (collector, VM builder, probes).
              (import ./nix/test-flake-module.nix inputs)
              # Example containers (auto-discovered via import-tree).
              # We import them here so `xi check` from root runs the full
              # BDD suite in one command, but `oci.enableFlakeOutputs = false`
              # keeps the ~160 per-container apps/packages/checks out of
              # `nix flake show`.
              (import ./nix/examples.nix { })
              # Treefmt formatter and check.
              ./nix/treefmt.nix
              # Vale prose lint (aggressive profile).
              ./nix/lint-vale.nix
            ];
            oci.enabled = true;
            # Suppress auto-emission of oci.flake.{apps,packages,checks} so
            # the root flake output stays clean. BDD checks are still wired
            # manually in perSystem below.
            oci.enableFlakeOutputs = false;
            # Expose nix-lib's auto-generated `flake.tests` output at root
            # only (extenders and the BDD `./tests` flake keep it hidden).
            oci.flake.exposeUnitTests = true;
            debug = true;
            perSystem =
              {
                config,
                pkgs,
                lib,
                ...
              }:
              {
                # Enable turbo push backend for all containers.
                oci.turbo.enable = true;
                # Lock files live at <project-root>/oci/.
                oci.fromImageManifestRootPath = ./oci + "/";

                # Expose the aggregated BDD checks. `xi check` from root
                # builds these, running every runtime/deploy BDD spec in a
                # single VM plus the flake-level app-build test.
                checks =
                  lib.optionalAttrs (config.test.oci._bddVmCheck != null) {
                    bdd-vm = config.test.oci._bddVmCheck;
                  }
                  // lib.optionalAttrs (config.test.oci._bddAppsCheck != null) {
                    bdd-apps = config.test.oci._bddAppsCheck;
                  };

                # Opt-in multi-arch aggregate (design D8): NOT wired into
                # `checks.<sys>.*` because `nix flake check` unconditionally
                # builds every attr there, and cross-compile / emulated /
                # merge paths require a remote builder, QEMU binfmt, or a
                # live registry. Exposed under `packages.<sys>.multi-arch`
                # so it is buildable via `nix build .#multi-arch` (or the
                # explicit `nix build .#packages.<sys>.multi-arch`) but
                # never traversed by `nix flake check`. Task 8.5 wires a
                # workflow_dispatch job to build this on demand.
                packages.multi-arch =
                  let
                    layouts = lib.attrValues (config.oci.internal.multiArchOCILayouts or { });
                    mergeApps = lib.attrValues (config.oci.internal.mergeMultiArchApps or { });
                    parts = layouts ++ mergeApps;
                  in
                  pkgs.runCommand "nix-oci-multi-arch-aggregate"
                    {
                      # Force realisation of every multi-arch layout + merge
                      # app so a single `nix build .#multi-arch` covers all
                      # multi-arch build paths declared in the flake.
                      buildInputs = parts;
                    }
                    ''
                      mkdir -p "$out"
                      echo "multi-arch aggregate: ${toString (builtins.length parts)} derivation(s)" > "$out/report.txt"
                      ${lib.concatMapStringsSep "\n" (p: ''echo "${p}" >> "$out/report.txt"'') parts}
                    '';

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
                      vale
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

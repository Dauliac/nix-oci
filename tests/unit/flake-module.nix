# Unit tests — nix-unit integration for lib function tests.
#
# nix-lib already generates flake.tests from the `tests = { ... }` fields
# in nix-lib.lib.oci.* declarations (16+ functions have inline tests).
#
# nix-unit's flake-parts module:
# 1. Copies flake.tests → perSystem.nix-unit.tests.system-agnostic
# 2. Generates perSystem.checks.nix-unit (runs nix-unit in sandbox)
#
# So `nix flake check` automatically runs all lib unit tests.
{ inputs, ... }:
let
  checksLib = import ../../nix/lib/container-checks.nix;
in
{
  imports = [
    inputs.nix-lib.inputs.nix-unit.modules.flake.default
  ];

  perSystem =
    { lib, ... }:
    let
      checks = checksLib { inherit lib; };
    in
    {
      nix-unit.allowNetwork = true;
      nix-unit.inputs = {
        inherit (inputs)
          nixpkgs
          nix-lib
          flake-parts
          import-tree
          nix2container
          ;
      };

      # Tests for checks sub-namespace (nix-lib doesn't recurse into sub-namespaces)
      nix-unit.tests = {
        "test hasNixStoreConflict detects hostStore + installNix conflict" = {
          expr = checks.hasNixStoreConflict {
            nix.hostStore = true;
            installNix = true;
          };
          expected = true;
        };
        "test hasNixStoreConflict detects hostDaemon + installNix conflict" = {
          expr = checks.hasNixStoreConflict {
            nix.hostDaemon = true;
            installNix = true;
          };
          expected = true;
        };
        "test hasNixStoreConflict no conflict with hostStore only" = {
          expr = checks.hasNixStoreConflict {
            nix.hostStore = true;
            installNix = false;
          };
          expected = false;
        };
        "test hasNixStoreConflict no conflict with installNix only" = {
          expr = checks.hasNixStoreConflict {
            nix.hostStore = false;
            installNix = true;
          };
          expected = false;
        };
        "test hasNixStoreConflict no conflict when both disabled" = {
          expr = checks.hasNixStoreConflict { };
          expected = false;
        };
      };
    };
}

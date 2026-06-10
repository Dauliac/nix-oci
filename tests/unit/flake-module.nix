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
{
  imports = [
    inputs.nix-lib.inputs.nix-unit.modules.flake.default
  ];

  perSystem =
    { ... }:
    {
      nix-unit.inputs = {
        inherit (inputs) nixpkgs nix-lib;
      };
    };
}

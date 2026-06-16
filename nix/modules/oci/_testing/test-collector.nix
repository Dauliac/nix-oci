# Collects BDD test specs from .test.nix files.
#
# Declares the test.oci.perContainer option tree where .test.nix files
# contribute their BDD specs. Discovers .test.nix files via discoverModules
# and imports them as flake-parts modules.
{
  lib,
  flake-parts-lib,
  ...
}:
let
  testSpecType = import ./_option-test-spec.nix { inherit lib; };
  discoverModules = import ../../../lib/discoverModules.nix { inherit lib; };
  filters = import ../../../lib/discoverFilters.nix { inherit lib; };

  # Discover .test.nix files from the _tests directory.
  # These are flake-parts modules that set config.perSystem.test.oci.perContainer.*.
  # The _tests/ dir is _-prefixed so import-tree skips it (avoids importing
  # .test.nix files as submodule options). Only the test-collector imports them.
  testModules = discoverModules {
    dir = ../containers/_tests;
    filter = filters.test;
  };
in
{
  # Import discovered .test.nix files as flake-parts modules.
  imports = testModules;

  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { ... }:
    {
      options.test.oci.perContainer = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf testSpecType);
        default = { };
        description = ''
          BDD test specs contributed by .test.nix files.

          Outer key = option group (e.g. "hardening-seccomp").
          Inner key = scenario name (e.g. "blocks-dangerous-syscalls").
          Value = test spec with BDD metadata + assertions.
        '';
      };
    }
  );
}

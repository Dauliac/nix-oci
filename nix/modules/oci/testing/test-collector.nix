# Collects BDD test specs from .test.nix files.
#
# Declares the test.oci.perContainer option tree where .test.nix files
# contribute their BDD specs. Collection logic is wired in F3.
{
  lib,
  flake-parts-lib,
  ...
}:
let
  testSpecType = import ./_option-test-spec.nix { inherit lib; };
in
{
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

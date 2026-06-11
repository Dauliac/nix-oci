# Sink for _tests definitions contributed by shared option files.
#
# The shared _options/ files write to config._tests.<optionName> with inline
# test specs. In the flake-parts path, perContainer.nix declares _tests as a
# proper option. In the deploy path, we just need to absorb those definitions
# without error -- deploy containers don't use the test framework.
{ lib, ... }:
{
  options._tests = lib.mkOption {
    type = lib.types.attrsOf lib.types.raw;
    default = { };
    internal = true;
    description = "Absorbed by deploy; used only in flake-parts test infrastructure.";
  };
}

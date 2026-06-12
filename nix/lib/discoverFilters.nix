# Preset filename filters for discoverModules.
#
# Three filters to route co-located files into separate module streams:
#   filters.options — *.nix (excluding *.lib.nix, *.test.nix, default.nix)
#   filters.lib     — *.lib.nix
#   filters.test    — *.test.nix
{ lib }:
{
  options =
    name:
    lib.hasSuffix ".nix" name
    && !lib.hasSuffix ".lib.nix" name
    && !lib.hasSuffix ".test.nix" name
    && name != "default.nix";

  lib = name: lib.hasSuffix ".lib.nix" name;

  test = name: lib.hasSuffix ".test.nix" name;
}

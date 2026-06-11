# nix-lib wrapper for the pure discoverModules function.
# For option-type definitions, use the pure version directly:
#   import ../../../lib/discoverModules.nix { inherit lib; }
# This nix-lib registration makes it available in config blocks as:
#   config.lib.flake.oci.discoverModules
{ lib, ... }:
let
  pure = import ../../../lib/discoverModules.nix { inherit lib; };
in
{
  nix-lib.lib.oci.discoverModules = {
    type = lib.types.functionTo (lib.types.listOf lib.types.path);
    description = ''
      Recursively discover .nix module files in a directory,
      excluding _-prefixed subdirectories.
      Returns a list of paths suitable for `imports` or `staticModules`.
    '';
    file = "nix/lib/discoverModules.nix";
    fn = pure;
  };
}

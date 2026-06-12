# Recursively wrap all leaf values in an attrset with a given priority.
# Used by the per-container bridge to propagate flake-level oci defaults.
{ lib, ... }:
{
  nix-lib.lib.oci.mkDefaultsRecursive = {
    type = lib.types.functionTo (lib.types.functionTo lib.types.attrs);
    description = ''
      Recursively wrap all leaf values in an attrset with lib.mkOverride at
      the given priority. Used by the per-container bridge to propagate
      flake-level oci.* defaults at a priority below mkDefault (1000)
      so that per-container computed defaults can override them.
    '';
    file = "nix/modules/oci/lib/mkDefaultsRecursive.nix";
    fn =
      priority: attrs:
      lib.mapAttrsRecursiveCond builtins.isAttrs (_path: value: lib.mkOverride priority value) attrs;
  };
}

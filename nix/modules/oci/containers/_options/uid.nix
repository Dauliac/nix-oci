# Shared: UID for non-root container user.
{ lib, ... }:
{
  options.uid = lib.mkOption {
    type = lib.types.int;
    default = 4000;
    description = ''
      UID for the non-root container user.

      Only used when `isRoot = false`. The default (4000) avoids
      conflicts with system UIDs (< 1000) and common application
      UIDs while remaining within the standard UID range.
    '';
    example = 1000;
  };
}

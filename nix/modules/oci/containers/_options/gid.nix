# Shared: GID for non-root container user.
{ lib, ... }:
{
  options.gid = lib.mkOption {
    type = lib.types.int;
    default = 4000;
    description = ''
      GID for the non-root container user's primary group.

      Only used when `isRoot = false`. The default (4000) matches
      the default UID to keep user/group mapping simple.
    '';
    example = 1000;
  };
}

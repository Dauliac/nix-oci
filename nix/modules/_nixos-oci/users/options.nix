# NixOS-only user options: uid and gid.
#
# user and isRoot come from the shared _options/ files via
# container-options-namespace.nix. uid and gid are NixOS-only
# because they're used for shadow file generation and not
# currently exposed in the flake-parts API.
{ lib, ... }:
{
  options.oci.container = {
    uid = lib.mkOption {
      type = lib.types.int;
      default = 4000;
      description = "UID for non-root container user.";
    };
    gid = lib.mkOption {
      type = lib.types.int;
      default = 4000;
      description = "GID for non-root container user.";
    };
  };
}

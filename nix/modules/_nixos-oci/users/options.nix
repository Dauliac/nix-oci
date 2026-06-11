{ lib, ... }:
{
  options.oci.container = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Container user name.";
    };
    isRoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the container runs as root.";
    };
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

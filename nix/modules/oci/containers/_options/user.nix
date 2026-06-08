# Shared: container user.
{ lib, ... }:
{
  options.user = lib.mkOption {
    type = lib.types.str;
    default = "root";
    description = "User to run the container process as.";
  };
}

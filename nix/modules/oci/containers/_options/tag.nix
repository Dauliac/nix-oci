# Shared: image tag.
{ lib, ... }:
{
  options.tag = lib.mkOption {
    type = lib.types.str;
    default = "latest";
    description = "OCI image tag.";
  };
}

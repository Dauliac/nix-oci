# OCI registry option
{ lib, ... }:
{
  options.oci.registry = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "The OCI registry to use for pushing and pulling images.";
  };
}

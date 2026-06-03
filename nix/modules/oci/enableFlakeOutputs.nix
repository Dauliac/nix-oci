# OCI enableFlakeOutputs option
{ lib, ... }:
{
  options.oci.enableFlakeOutputs = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to automatically expose OCI apps, packages, and checks as flake outputs.";
    default = true;
    example = false;
  };
}

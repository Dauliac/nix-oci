{ lib, ... }:
{
  options.oci.flake.outputs.packages = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Expose `oci-<name>` gated image packages.";
  };
}

# Shared: OCI image labels/metadata.
{ lib, ... }:
{
  options.labels = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "OCI image labels (metadata key-value pairs).";
  };
}

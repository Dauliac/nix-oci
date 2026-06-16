# Shared: image tag.
{
  lib,
  ...
}:
let
  example = "v1.0.0";
in
{
  options.tag = lib.mkOption {
    type = lib.types.str;
    default = "latest";
    description = "OCI image tag.";
    inherit example;
  };
}

# Shared: image name (defaults to container attribute name).
{
  name,
  lib,
  ...
}:
let
  example = "my-custom-image";
in
{
  options.name = lib.mkOption {
    type = lib.types.str;
    default = name;
    description = "OCI image name. Defaults to the container attribute name.";
    inherit example;
  };
}

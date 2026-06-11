# Shared: image name (defaults to container attribute name).
{
  name,
  lib,
  pkgs,
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

  config._tests.name = {
    level = "eval";
    default = {
      package = pkgs.hello;
    };
    override = {
      package = pkgs.hello;
      name = example;
    };
  };
}

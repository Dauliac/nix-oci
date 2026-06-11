# Shared: image tag.
{
  lib,
  pkgs,
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

  config._tests.tag = {
    level = "eval";
    default = {
      package = pkgs.hello;
    };
    override = {
      package = pkgs.hello;
      tag = example;
    };
  };
}

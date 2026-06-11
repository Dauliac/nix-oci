# Shared: container user.
{
  lib,
  pkgs,
  ...
}:
let
  example = "nobody";
in
{
  options.user = lib.mkOption {
    type = lib.types.str;
    default = "root";
    description = "User to run the container process as.";
    inherit example;
  };

  config._tests.user = {
    level = "eval";
    default = {
      package = pkgs.hello;
    };
    override = {
      package = pkgs.hello;
      user = example;
    };
  };
}

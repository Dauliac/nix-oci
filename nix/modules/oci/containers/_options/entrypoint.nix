# Shared: entrypoint command.
{
  lib,
  pkgs,
  ...
}:
let
  example = [
    "/bin/hello"
    "--greeting"
    "world"
  ];
in
{
  options.entrypoint = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "OCI entrypoint (command + arguments).";
    inherit example;
  };

  config._tests.entrypoint = {
    level = "inspect";
    default = {
      package = pkgs.hello;
    };
    override = {
      package = pkgs.hello;
      entrypoint = example;
    };
    assertions.imageConfig.Entrypoint = example;
  };
}

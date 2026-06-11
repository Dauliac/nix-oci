# Shared: runtime environment variables.
{
  lib,
  pkgs,
  ...
}:
let
  example = {
    RUST_LOG = "info";
  };
in
{
  options.environment = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Environment variables baked into the OCI manifest and passed to the runner.";
    inherit example;
  };

  config._tests.environment = {
    level = "inspect";
    default = {
      package = pkgs.hello;
    };
    override = {
      package = pkgs.hello;
      environment = example;
    };
    assertions.imageConfig.Env = {
      RUST_LOG = "info";
    };
  };
}

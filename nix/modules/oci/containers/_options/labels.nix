# Shared: OCI image labels/metadata.
{
  lib,
  pkgs,
  ...
}:
let
  example = {
    "org.opencontainers.image.title" = "my-app";
    "org.opencontainers.image.version" = "1.0.0";
  };
in
{
  options.labels = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "OCI image labels (metadata key-value pairs).";
    inherit example;
  };

  config._tests.labels = {
    level = "inspect";
    default = {
      package = pkgs.hello;
    };
    override = {
      package = pkgs.hello;
      labels = example;
    };
    assertions.imageConfig.Labels = example;
  };
}

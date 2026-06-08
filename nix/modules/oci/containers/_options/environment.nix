# Shared: runtime environment variables.
{ lib, ... }:
{
  options.environment = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Environment variables baked into the OCI manifest and passed to the runner.";
    example = {
      RUST_LOG = "info";
    };
  };
}

# Per-container: runtime environment variables for the runner service.
{ lib, ... }:
{
  options.environment = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Environment variables passed to the container at runtime.";
    example = {
      RUST_LOG = "info";
    };
  };
}

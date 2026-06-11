{ lib, ... }:
{
  options.oci.container.performance.allocatorConfig = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Per-allocator tuning parameters (env var keys/values).";
  };
}

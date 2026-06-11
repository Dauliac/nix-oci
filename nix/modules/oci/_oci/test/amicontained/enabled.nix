{ lib, ... }:
{
  options.test.amicontained.enabled = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable amicontained container introspection globally for all containers.";
    default = false;
  };
}

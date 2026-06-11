{ lib, ... }:
{
  options.oci.container.environment = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "User-provided environment variables forwarded from the flake-parts container options.";
  };
}

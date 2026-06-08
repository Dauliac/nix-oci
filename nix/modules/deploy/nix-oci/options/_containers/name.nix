# Per-container: image name (defaults to container attribute name).
{ name, lib, ... }:
{
  options.name = lib.mkOption {
    type = lib.types.str;
    default = name;
    description = "OCI image name. Defaults to the container attribute name.";
  };
}

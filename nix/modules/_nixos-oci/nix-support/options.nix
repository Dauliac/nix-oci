{ lib, ... }:
{
  options.oci.container.installNix = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to install Nix in the container.";
  };
}

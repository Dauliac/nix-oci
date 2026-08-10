{ lib, ... }:
{
  options.oci.flake.outputs.loadDocker = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Expose `oci-load-docker-<name>` apps (load into Docker).";
  };
}

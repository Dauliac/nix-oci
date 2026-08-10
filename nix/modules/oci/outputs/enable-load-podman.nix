{ lib, ... }:
{
  options.oci.flake.outputs.loadPodman = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Expose `oci-load-podman-<name>` apps (load into Podman).";
  };
}

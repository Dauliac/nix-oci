{ lib, ... }:
{
  options.oci.flake.outputs.push = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Expose `oci-push-<name>` apps (push to registry).";
  };
}

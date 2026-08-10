{ lib, ... }:
{
  options.oci.flake.outputs.sandbox = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Expose `oci-sandbox-<name>` apps (bubblewrap shell).";
  };
}

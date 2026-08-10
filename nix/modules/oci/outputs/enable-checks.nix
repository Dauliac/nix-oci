{ lib, ... }:
{
  options.oci.flake.outputs.checks = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Expose `oci-gate-<name>` checks. Disabled by default since the gate is already enforced by packages and apps.";
  };
}

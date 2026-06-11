{ lib, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options.oci.test.dgoss.hermetic = mkOption {
    type = types.bool;
    description = ''
      Run dgoss as a pure Nix derivation (check) using podman
      inside the Nix sandbox.
      Requires `extra-sandbox-paths = /sys/fs/cgroup` in nix.conf.
    '';
    default = false;
  };
}

{ lib, ... }:
{
  options.test.dgoss.hermetic = lib.mkOption {
    type = lib.types.bool;
    description = ''
      Run dgoss as a pure Nix derivation (check) using podman.
      Requires `extra-sandbox-paths = /sys/fs/cgroup` in nix.conf.
    '';
    default = false;
  };
}

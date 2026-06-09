# Build the container root filesystem as a single buildEnv
#
# Composes package + dependencies + configFiles + shadow setup into one
# environment with standard paths (/bin, /lib, /etc, /home).
# Used by the deploy modules for non-NixOS containers.
{ lib, ... }:
let
  pure = import ../../../../lib/oci.nix { inherit lib; };
in
{
  nix-lib.lib.oci.mkRoot = {
    type = lib.types.functionTo lib.types.package;
    description = ''
      Build the container root filesystem as a single `buildEnv`.

      Composes package, dependencies, config files, and shadow setup
      (/etc/passwd, /etc/shadow, /etc/group) into one environment
      with `/bin`, `/lib`, `/etc`, `/home` paths.

      Used by deploy modules for non-NixOS container images.
    '';
    fn = pure.mkRoot;
  };
}

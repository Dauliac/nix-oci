# Generate /etc/passwd, /etc/shadow, /etc/group for the container user
#
# Creates the minimal user database files needed for a container.
# Root containers get a single root entry; non-root containers get
# root + a dedicated user with UID/GID 4000.
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  nix-lib.lib.oci.mkShadowSetup = {
    type = lib.types.functionTo (lib.types.listOf lib.types.package);
    description = ''
      Generate /etc/passwd, /etc/shadow, /etc/group derivations for a container.

      Root containers get a single `root` entry.
      Non-root containers get `root` + a dedicated user (UID/GID 4000)
      with a home directory.

      Returns a list of derivations to include in the image root.
    '';
        file = "nix/lib/oci.nix";
    fn = pure.mkShadowSetup;
  };
}

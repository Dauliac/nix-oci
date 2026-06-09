# OCI mkNixConfig - Build nix configuration file for containers
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkNixConfig = {
        type = lib.types.functionTo lib.types.package;
        description = "Build nix configuration file for containers";
        file = "nix/modules/oci/lib/mkNixConfig.nix";
        fn =
          { }:
          pkgs.writeText "etc/nix/nix.conf" ''
            experimental-features = nix-command flakes
            build-users-group = nixbld
            sandbox = false
          '';
      };
    };
}

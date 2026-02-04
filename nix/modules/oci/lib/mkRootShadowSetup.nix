# OCI mkRootShadowSetup - Build shadow files for root user containers
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkRootShadowSetup = {
        type = lib.types.functionTo (lib.types.listOf lib.types.package);
        description = "Build passwd, shadow, group, and gshadow files for containers run as root user";
        fn =
          { }:
          with pkgs;
          [
            (writeTextDir "etc/shadow" ''
              root:!x:::::::
            '')
            (writeTextDir "etc/passwd" ''
              root:x:0:0::/root:${runtimeShell}
            '')
            (writeTextDir "etc/group" ''
              root:x:0:
            '')
            (writeTextDir "etc/gshadow" ''
              root:x::
            '')
          ];
      };
    };
}

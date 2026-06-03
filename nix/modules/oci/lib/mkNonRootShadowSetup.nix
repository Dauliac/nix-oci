# OCI mkNonRootShadowSetup - Build shadow files for non-root user containers
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkNonRootShadowSetup = {
        type = lib.types.functionTo (lib.types.listOf lib.types.package);
        description = "Build passwd, shadow, group, and gshadow files for containers run as non-root user";
        fn =
          {
            user,
            uid ? 4000,
            gid ? uid,
          }:
          with pkgs;
          [
            (writeTextDir "etc/shadow" ''
              root:!x:::::::
              ${user}:!:::::::
            '')
            (writeTextDir "etc/passwd" ''
              root:x:0:0::/root:${runtimeShell}
              ${user}:x:${toString uid}:${toString gid}::/home/${user}:
            '')
            (writeTextDir "etc/group" ''
              root:x:0:
              ${user}:x:${toString gid}:
            '')
            (writeTextDir "etc/gshadow" ''
              root:x::
              ${user}:x::
            '')
          ];
      };
    };
}

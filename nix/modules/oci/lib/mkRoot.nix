# OCI mkRoot - Build container root filesystem
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
    in
    {
      nix-lib.lib.oci.mkRoot = {
        type = lib.types.functionTo lib.types.package;
        description = "Build container root filesystem with package, user setup, and dependencies";
        fn =
          {
            tag,
            user,
            package ? null,
            dependencies ? [ ],
          }:
          let
            package' = if package == null then [ ] else [ package ];
            shadowSetup =
              if user == "root" then
                ociLib.mkRootShadowSetup { }
              else if user != null && user != "" then
                ociLib.mkNonRootShadowSetup { inherit user; }
              else
                throw "User must be specified";
          in
          pkgs.buildEnv {
            name = "root";
            version = tag;
            paths = package' ++ shadowSetup ++ dependencies ++ [
              # Standard FHS temp directories
              (pkgs.runCommand "fhs-tmp" {} ''
                mkdir -p $out/tmp $out/var/tmp
              '')
            ];
            pathsToLink = [
              "/bin"
              "/lib"
              "/etc"
            ];
          };
      };
    };
}

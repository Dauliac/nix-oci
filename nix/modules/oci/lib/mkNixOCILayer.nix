# OCI mkNixOCILayer - Build the Nix layer for containers with Nix support
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
      nix-lib.lib.oci.mkNixOCILayer = {
        type = lib.types.functionTo lib.types.package;
        description = "Build the Nix layer for containers with Nix support";
        fn =
          {
            perSystemConfig,
            user,
          }:
          perSystemConfig.packages.nix2container.buildLayer {
            copyToRoot = [
              (pkgs.buildEnv {
                name = "root";
                paths =
                  with pkgs;
                  [
                    coreutils
                    nix
                  ]
                  ++ (ociLib.mkNixShadowSetup { });
                pathsToLink = [
                  "/bin"
                  "/etc"
                ];
              })
            ];
            config = {
              Env = [
                "NIX_PAGER=cat"
                "USER=${user}"
                "HOME=/"
              ];
            };
          };
      };
    };
}

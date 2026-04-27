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
          { perSystemConfig }:
          perSystemConfig.packages.nix2container.buildLayer {
            copyToRoot = [
              (pkgs.buildEnv {
                name = "root";
                paths =
                  with pkgs;
                  [
                    bashInteractive
                    # Provide /bin/sh -> bash for tools that expect a POSIX shell
                    (pkgs.runCommand "sh-symlink" {} ''
                      mkdir -p $out/bin
                      ln -s ${pkgs.bashInteractive}/bin/bash $out/bin/sh
                    '')
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
          };
      };
    };
}

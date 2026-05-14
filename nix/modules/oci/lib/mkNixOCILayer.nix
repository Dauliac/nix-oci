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

      # Standard FHS directories that must exist as real directories
      # (not symlinks). Placed outside buildEnv as a separate copyToRoot
      # entry so nix2container creates them at the filesystem root.
      fhsDirs = pkgs.runCommand "fhs-dirs" { } ''
        mkdir -p $out/tmp $out/var/tmp
      '';
    in
    {
      nix-lib.lib.oci.mkNixOCILayer = {
        type = lib.types.functionTo lib.types.package;
        description = "Build the Nix layer for containers with Nix support";
        fn =
          {
            perSystemConfig,
            # Optional container user for shadow setup.
            # When non-root, mkNixShadowSetup adds the user to
            # passwd/group/shadow alongside the nixbld build users.
            user ? null,
            home ? null,
          }:
          perSystemConfig.packages.nix2container.buildLayer {
            copyToRoot = [
              (pkgs.buildEnv {
                name = "root";
                ignoreCollisions = true;
                paths =
                  with pkgs;
                  [
                    bashInteractive
                    # Provide /bin/sh -> bash for tools that expect a POSIX shell
                    # and standard FHS temp directories
                    (pkgs.runCommand "fhs-base" { } ''
                      mkdir -p $out/bin $out/tmp $out/var/tmp
                      ln -s ${pkgs.bashInteractive}/bin/bash $out/bin/sh
                    '')
                    # Enable flakes and nix-command by default
                    (pkgs.writeTextDir "etc/nix/nix.conf" ''
                      experimental-features = nix-command flakes
                    '')
                    coreutils
                    nix
                  ]
                  ++ (ociLib.mkNixShadowSetup ({
                  } // lib.optionalAttrs (user != null) {
                    inherit user;
                  } // lib.optionalAttrs (home != null) {
                    inherit home;
                  }));
                pathsToLink = [
                  "/bin"
                  "/etc"
                  "/etc/nix"
                ];
              })
              fhsDirs
            ];
          };
      };
    };
}

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

      # Config files placed as a separate copyToRoot entry — buildEnv
      # can't merge subdirectories under /etc when the nix package
      # already provides /etc as a top-level symlink target.
      etcConfig = pkgs.runCommand "etc-config" {} ''
        mkdir -p $out/etc/nix $out/etc/containers
        echo 'experimental-features = nix-command flakes' > $out/etc/nix/nix.conf
        echo '${builtins.toJSON { default = [{ type = "insecureAcceptAnything"; }]; }}' > $out/etc/containers/policy.json
      '';
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
              # Separate from buildEnv: nix.conf + containers/policy.json
              # nix2container merges multiple copyToRoot entries at the
              # filesystem level, so these files land alongside buildEnv's
              # /etc without conflicting.
              etcConfig
            ];
          };
      };
    };
}

{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    mdDoc
    types
    ;
in
{
  options.lib = {
    mkCheckDive = mkOption {
      description = mdDoc "A function to create a check that runs dive on a built image";
      type = types.functionTo types.package;
      default =
        {
          oci,
          pkgs,
          perSystemConfig,
        }:
        let
          archive = config.lib.mkDockerArchive {
            inherit oci pkgs;
            inherit (perSystemConfig.packages) skopeo;
          };
        in
        pkgs.runCommandLocal "dive-check"
          {
            buildInputs = [
              perSystemConfig.packages.dive
            ];
          }
          ''
            set -e
            dive --ci --json $out docker-archive://${archive}
          '';
    };
  };
}

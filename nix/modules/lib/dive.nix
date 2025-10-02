{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options.oci.lib = {
    mkCheckDive = mkOption {
      description = "A function to create a check that runs dive on a built image";
      type = types.functionTo types.package;
      default =
        {
          oci,
          pkgs,
          perSystemConfig,
        }:
        let
          archive = config.oci.lib.mkDockerArchive {
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

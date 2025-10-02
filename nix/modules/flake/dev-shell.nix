{
  config,
  lib,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkIf
    ;
in
{
  config = mkIf config.oci.enabled {
    perSystem =
      {
        config,
        pkgs,
        ...
      }:
      {
        devShells.default = mkIf cfg.oci.enableDevShell (
          pkgs.mkShell {
            # NOTE: transform config.packages attrset into list
            packages = lib.attrValues config.oci.packages;
            shellHook = ''
              ${config.packages.oci-updatePulledManifestsLocks}/bin/update-pulled-oci-manifests-locks
            '';
          }
        );
      };
  };
}

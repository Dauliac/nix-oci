# NixOS config integration - assertions and mainService -> package derivation
#
# This module handles:
# - Mutual exclusion assertion (package vs mainService)
# - Type="forking" warning
# - Auto-deriving package from mainService (so name/tag auto-derive too)
#
# Everything else (entrypoint, shadow, env, configFiles, dependencies) is now
# managed by the NixOS module (nix/nixos/oci-container.nix) via the eval.
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        {
          config,
          name,
          ...
        }:
        let
          nixosCfg = config.nixosConfig;
          enabled = nixosCfg.enable;
          eval = nixosCfg.eval;
          mainService = nixosCfg.mainService or null;
          out = eval.oci.container._output;

          servicePackage = out.servicePackage or null;
          serviceType =
            if out.serviceData or null != null then out.serviceData.serviceType or "simple" else "simple";
        in
        {
          options.nixosConfig._checks = lib.mkOption {
            type = lib.types.str;
            internal = true;
            readOnly = true;
            description = "Internal: force-evaluated during build to check assertions.";
            default =
              let
                packageConflict =
                  enabled
                  && mainService != null
                  && config.package != null
                  && servicePackage != null
                  && config.package != servicePackage;
                isForkingService = enabled && mainService != null && serviceType == "forking";
              in
              (
                if packageConflict then
                  throw ''
                    Container "${name}": cannot set both `package` and `nixosConfig.mainService`.
                    - To let the NixOS service provide the package: remove `package`, set `mainService`.
                    - To control the package yourself: remove `mainService`, set `package` explicitly.
                  ''
                else
                  ""
              )
              + (
                if isForkingService then
                  builtins.trace ''
                    WARNING: Container "${name}": service "${mainService}" uses Type="forking".
                    The process will daemonize and the container may exit immediately.
                  '' ""
                else
                  ""
              );
          };

          config = lib.mkIf (enabled && mainService != null && servicePackage != null) {
            # Auto-derive package from mainService so name/tag cascade
            package = lib.mkDefault servicePackage;
          };
        };
    };
}

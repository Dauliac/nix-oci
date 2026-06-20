# NixOS config integration - assertions and mainService -> package derivation
#
# Delegates all check logic to the shared container-checks.nix library.
# This module handles:
# - Force-evaluating _checks during build (errors + warnings)
# - Auto-deriving package from mainService (so name/tag auto-derive too)
{ lib, ... }:
let
  checksLib = import ../../../../lib/container-checks.nix { inherit lib; };
in
{
  config.perSystem =
    { pkgs, ... }:
    {
      oci.perContainer =
        {
          config,
          name,
          ...
        }:
        let
          nixosCfg = config.nixosConfig;
          mainService = config.mainService or nixosCfg.mainService or null;
          enabled = mainService != null || nixosCfg.modules != [ ];
          eval = nixosCfg.eval;
          out = eval.oci.container._output;
          servicePackage = out.servicePackage or null;
        in
        {
          options.nixosConfig._checks = lib.mkOption {
            type = lib.types.str;
            internal = true;
            readOnly = true;
            description = "Internal: force-evaluated during build to check assertions.";
            default = checksLib.runChecks {
              inherit name enabled mainService;
              system = pkgs.system;
              containerConfig = config;
              evalOutput = out;
            };
          };

          config = lib.mkIf (enabled && mainService != null && servicePackage != null) {
            # Auto-derive package from mainService so name/tag cascade
            package = lib.mkDefault servicePackage;
          };
        };
    };
}

# Deploy: integration checks and mainService -> package auto-derivation.
#
# Mirrors flake-parts nixosConfig/integration.nix using the shared
# container-checks.nix library. Force-evaluated via _checks during build.
{
  name,
  config,
  lib,
  ...
}:
let
  checksLib = import ../../../../../lib/container-checks.nix { inherit lib; };
  nixosCfg = config.nixosConfig;
  enabled = nixosCfg.mainService != null || nixosCfg.modules != [ ];
  mainService = nixosCfg.mainService or null;
  eval = nixosCfg.eval or null;
  out = if eval != null then eval.oci.container._output else null;
  servicePackage = if out != null then out.servicePackage or null else null;
in
{
  options.nixosConfig._checks = lib.mkOption {
    type = lib.types.str;
    internal = true;
    readOnly = true;
    description = "Internal: force-evaluated during build to check assertions.";
    default =
      if enabled && out != null then
        checksLib.runChecks {
          inherit name enabled mainService;
          containerConfig = config;
          evalOutput = out;
        }
      else
        "";
  };

  config = lib.mkIf (enabled && mainService != null && servicePackage != null) {
    # Auto-derive package from mainService so name/tag cascade
    package = lib.mkDefault servicePackage;
  };
}

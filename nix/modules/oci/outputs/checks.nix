# OCI checks intermediate output
{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, ... }:
    {
      options.oci.flake.checks = mkOption {
        type = types.attrsOf types.package;
        description = "OCI-related checks that can be exposed as flake outputs.";
        readOnly = true;
        default =
          config.oci.internal.prefixedDiveChecks
          // config.oci.internal.prefixedDgossChecks
          // config.oci.internal.prefixedPolicyConftestChecks
          // config.oci.internal.prefixedLintDockleChecks
          // config.oci.internal.prefixedCredentialsLeakTrivyChecks
          // config.oci.internal.prefixedSBOMSyftChecks;
      };
    }
  );
}

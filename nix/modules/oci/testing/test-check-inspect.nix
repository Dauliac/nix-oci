# Generate inspect-level checks from BDD test specs.
#
# Registers mkInspectCheck via nix-lib. Uses mkRegoFromBddAssertions
# from config.lib.oci (registered in rego-gen.nix).
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
    {
      config,
      pkgs,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
      allSpecs = config.test.oci.perContainer or { };
      hasRegoGen = (ociLib.test.mkRegoFromBddAssertions or null) != null;

      inspectSpecs = lib.concatMapAttrs (
        group: scenarios:
        lib.concatMapAttrs (
          name: spec: if spec.level == "inspect" then { "${group}--${name}" = spec; } else { }
        ) scenarios
      ) allSpecs;

      mkInspectCheckFn =
        {
          name,
          spec,
        }:
        let
          regoDir = ociLib.test.mkRegoFromBddAssertions {
            assertions = spec.assertions;
            testName = name;
          };
        in
        pkgs.runCommandLocal "inspect-check-${name}" { } ''
          echo "Generated Rego policy for ${name}:"
          cat ${regoDir}/*.rego
          touch $out
        '';
    in
    {
      options.oci.internal.inspectChecks = mkOption {
        type = types.attrsOf types.package;
        internal = true;
        readOnly = true;
        default = lib.optionalAttrs hasRegoGen (
          lib.mapAttrs' (
            name: spec:
            lib.nameValuePair "bdd-inspect-${name}" (mkInspectCheckFn {
              inherit name spec;
            })
          ) inspectSpecs
        );
        description = "Inspect-level BDD checks.";
      };
    }
  );
}

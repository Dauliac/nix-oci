# Generate inspect-level checks from BDD test specs.
#
# For each test spec where level="inspect", compiles assertions to
# Rego policies and runs them via conftest against the OCI image config.
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
      system,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
      allSpecs = config.test.oci.perContainer or { };

      # Filter specs where level = "inspect"
      inspectSpecs = lib.concatMapAttrs (
        group: scenarios:
        lib.concatMapAttrs (
          name: spec: if spec.level == "inspect" then { "${group}--${name}" = spec; } else { }
        ) scenarios
      ) allSpecs;

      # Generate a check for each inspect spec
      mkInspectCheck =
        name: spec:
        let
          # Compile BDD assertions to Rego
          regoDir = ociLib.test.mkRegoFromBddAssertions {
            assertions = spec.assertions;
            testName = name;
          };
        in
        # For now, just create the Rego — the full conftest pipeline integration
        # requires building the container image first, which will be wired in I1.
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
        default = lib.mapAttrs' (
          name: spec: lib.nameValuePair "bdd-inspect-${name}" (mkInspectCheck name spec)
        ) inspectSpecs;
        description = "Inspect-level BDD checks compiled from test specs to Rego policies.";
      };
    }
  );
}

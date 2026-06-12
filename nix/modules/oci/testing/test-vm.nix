# Extract container configs from runtime/deploy BDD test specs.
#
# Filters test specs where level in {runtime, deploy} and extracts
# their container attrsets for injection into the NixOS VM test.
# The VM assembly and test script generation is handled by I1.
{
  lib,
  flake-parts-lib,
  ...
}:
{
  config.perSystem =
    { config, ... }:
    let
      allSpecs = config.test.oci.perContainer;

      # Filter specs where level requires a VM (runtime or deploy)
      vmSpecs = lib.concatMapAttrs (
        group: scenarios:
        lib.concatMapAttrs (
          name: spec:
          if
            builtins.elem spec.level [
              "runtime"
              "deploy"
            ]
          then
            { "${group}--${name}" = spec; }
          else
            { }
        ) scenarios
      ) allSpecs;

      # Extract container configs from specs, keyed by spec name
      vmContainers = lib.mapAttrs (_name: spec: spec.container) vmSpecs;

      # Extract assertions for Python test generation (used by I1)
      vmAssertions = lib.mapAttrs (_name: spec: {
        inherit (spec) assertions;
        given = spec.given or "";
        "when" = spec."when" or "";
        "then" = spec."then" or "";
      }) vmSpecs;
    in
    {
      options.test.oci._vmContainers = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        internal = true;
        readOnly = true;
        default = vmContainers;
        description = "Container configs extracted from runtime/deploy BDD specs.";
      };

      options.test.oci._vmAssertions = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        internal = true;
        readOnly = true;
        default = vmAssertions;
        description = "Assertions extracted from runtime/deploy BDD specs.";
      };
    };
}

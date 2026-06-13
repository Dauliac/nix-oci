# Extract container configs from runtime/deploy BDD test specs.
#
# Exposes extracted data as internal options for the VM test builder.
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, ... }:
    let
      allSpecs = config.test.oci.perContainer or { };

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
    in
    {
      options.test.oci._vmContainers = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        internal = true;
        readOnly = true;
        default = lib.mapAttrs (_: spec: spec.container) vmSpecs;
        description = "Container configs extracted from runtime/deploy BDD specs.";
      };

      options.test.oci._vmAssertions = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        internal = true;
        readOnly = true;
        default = lib.mapAttrs (_: spec: {
          inherit (spec) assertions;
          given = spec.given or "";
          "when" = spec."when" or "";
          "then" = spec."then" or "";
        }) vmSpecs;
        description = "Assertions extracted from runtime/deploy BDD specs.";
      };
    }
  );
}

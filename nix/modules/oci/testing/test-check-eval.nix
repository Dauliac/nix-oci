# Generate eval-level checks from BDD test specs.
#
# For each test spec where level="eval", creates a nix derivation
# that evaluates the container config and asserts no error.
# Registers mkEvalCheck via nix-lib.
{ lib, ... }:
let
  inherit (lib) types;
in
{
  config.perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      allSpecs = config.test.oci.perContainer or { };
      collectedModules = config.oci.perContainer._collectedModules or [ ];

      evalSpecs = lib.concatMapAttrs (
        group: scenarios:
        lib.concatMapAttrs (
          name: spec: if spec.level == "eval" then { "${group}--${name}" = spec; } else { }
        ) scenarios
      ) allSpecs;

      mkEvalCheckFn =
        {
          name,
          spec,
          collectedModules ? config.oci.perContainer._collectedModules or [ ],
        }:
        let
          eval = lib.evalModules {
            modules = collectedModules ++ [ { config = spec.container; } ];
            specialArgs = {
              inherit system pkgs;
              name = "__eval-test-${name}__";
              globalConfig = { };
              perSystemConfig = config;
            };
          };
        in
        pkgs.runCommandLocal "eval-check-${name}" { } ''
          echo "Evaluating container config for ${name}..."
          echo "${builtins.toJSON eval.config.entrypoint}" > /dev/null
          touch $out
        '';
    in
    {
      nix-lib.lib.oci.test = {
        mkEvalCheck = {
          type = types.functionTo types.package;
          description = "Create an eval-level BDD check derivation from a test spec.";
          file = "nix/modules/oci/testing/test-check-eval.nix";
          fn = mkEvalCheckFn;
        };
      };

      checks = lib.mapAttrs' (
        name: spec:
        lib.nameValuePair "bdd-eval-${name}" (mkEvalCheckFn {
          inherit name spec collectedModules;
        })
      ) evalSpecs;
    };
}

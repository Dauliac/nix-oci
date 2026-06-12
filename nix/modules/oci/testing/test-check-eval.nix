# Generate eval-level checks from BDD test specs.
#
# For each test spec where level="eval", creates a nix derivation
# that evaluates the container config and asserts no error.
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      allSpecs = config.test.oci.perContainer or { };
      collectedModules = config.oci.perContainer._collectedModules or [ ];

      # Filter specs where level = "eval"
      evalSpecs = lib.concatMapAttrs (
        group: scenarios:
        lib.concatMapAttrs (
          name: spec: if spec.level == "eval" then { "${group}--${name}" = spec; } else { }
        ) scenarios
      ) allSpecs;

      # Generate a check for each eval spec
      mkEvalCheck =
        name: spec:
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
          # Force evaluation of the container config
          echo "Evaluating container config for ${name}..."
          echo "${builtins.toJSON eval.config.entrypoint}" > /dev/null
          touch $out
        '';
    in
    {
      checks = lib.mapAttrs' (
        name: spec: lib.nameValuePair "bdd-eval-${name}" (mkEvalCheck name spec)
      ) evalSpecs;
    }
  );
}

# BDD assertion compiler: generates Rego policies from declarative test specs.
# The output directory is suitable for conftest's extraPolicyDirs.
{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) types;
in
{
  config.perSystem =
    { pkgs, ... }:
    {
      nix-lib.lib.oci.test = {
        mkRegoFromBddAssertions = {
          type = types.functionTo types.package;
          description = "Compile BDD assertions into a Rego policy directory.";
          file = "nix/modules/oci/testing/rego-gen.nix";
          fn =
            {
              assertions,
              testName ? "bdd",
            }:
            let
              safeName = lib.replaceStrings [ "-" "." ] [ "_" "_" ] testName;

              imageConfigRules = lib.concatStringsSep "\n" (
                lib.mapAttrsToList (
                  key: value:
                  let
                    jsonValue = builtins.toJSON value;
                  in
                  ''
                    deny contains msg if {
                      input.config.${key} != ${jsonValue}
                      msg := sprintf("BDD[${testName}]: expected Config.${key} = %v, got %v", [${jsonValue}, input.config.${key}])
                    }
                  ''
                ) (assertions.imageConfig or { })
              );

              labelRules = lib.concatStringsSep "\n" (
                lib.mapAttrsToList (key: value: ''
                  deny contains msg if {
                    not input.config.Labels["${key}"] == "${value}"
                    msg := sprintf("BDD[${testName}]: expected label ${key} = ${value}, got %v", [input.config.Labels["${key}"]])
                  }
                '') (assertions.labels or { })
              );
            in
            pkgs.writeTextDir "bdd-${testName}.rego" ''
              package bdd_${safeName}

              import rego.v1

              ${imageConfigRules}
              ${labelRules}
            '';
        };
      };
    };
}

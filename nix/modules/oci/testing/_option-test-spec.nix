# Shared type for option test specifications.
#
# Imported by:
# - perContainer.nix  → internal _tests collection (type-checks contributions)
# - option-tests.nix  → public oci.optionTests catalog (readOnly, documented)
#
# Prefixed with _ so import-tree does not auto-import this as a module.
{ lib }:
let
  inherit (lib) mkOption types;
in
types.submodule {
  options = {
    level = mkOption {
      type = types.enum [
        "eval"
        "build"
        "inspect"
        "runtime"
        "deploy"
      ];
      default = "eval";
      description = ''
        Test depth — determines what kind of check is generated:

        - `"eval"` — container config evaluates without error (cheapest).
        - `"build"` — OCI image builds successfully.
        - `"inspect"` — image metadata contains expected values.
        - `"runtime"` — container runs correctly in a NixOS VM.
        - `"deploy"` — full deploy + systemd integration in a NixOS VM.
      '';
    };

    default = mkOption {
      type = types.raw;
      default = { };
      description = ''
        Container config using only defaults.
        Tests that the option's default value produces a valid container.
      '';
    };

    override = mkOption {
      type = types.raw;
      default = { };
      description = ''
        Container config with the example value applied.
        Tests that overriding the option with its documented example works.
      '';
    };

    assertions = mkOption {
      type = types.submodule {
        options = {
          imageConfig = mkOption {
            type = types.attrsOf types.raw;
            default = { };
            description = "Expected fields in the OCI image config (for inspect-level tests).";
          };
          runtime = mkOption {
            type = types.lines;
            default = "";
            description = "Python test script for VM tests (for runtime/deploy-level tests).";
          };
        };
      };
      default = { };
      description = "Assertions to verify after building/running the container.";
    };

    exampleFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Link to an `examples/` file for documentation cross-reference.";
    };
  };
}

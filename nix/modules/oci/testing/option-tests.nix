# Public catalog of option-level tests.
#
# Materializes the internal _tests specs (contributed by each option file)
# into a public, read-only oci.optionTests namespace. This creates a
# documented "wall index" of all tested configurations.
#
# The catalog is populated lazily — the probe only runs when something
# accesses oci.optionTests (e.g. the test collector or doc generator).
{
  lib,
  flake-parts-lib,
  ...
}:
let
  testSpecType = import ./_option-test-spec.nix { inherit lib; };
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
      # Evaluate a minimal "probe" container to extract all _tests specs.
      # The _tests config is contributed by the static option modules,
      # so it is identical for every container instance.
      collectedModules = config.oci.perContainer._collectedModules;

      probeEval =
        (lib.evalModules {
          modules = collectedModules ++ [
            { config.package = pkgs.hello; }
          ];
          specialArgs = {
            name = "__test-probe__";
            inherit system pkgs;
            globalConfig = { };
            perSystemConfig = config;
          };
        }).config;
    in
    {
      options.oci.optionTests = lib.mkOption {
        type = lib.types.attrsOf testSpecType;
        readOnly = true;
        description = ''
          Catalog of all option-level tests.

          Each entry corresponds to one option file and defines two container
          configurations:

          - **default** — tests that the option's default value produces a valid container.
          - **override** — tests that the option's documented example value works.

          This catalog is read-only: it is populated automatically from
          `config._tests` specs defined in each option file.

          Use `nix build .#checks.<system>.option-<name>` to run a specific test.
        '';
      };

      config.oci.optionTests = probeEval._tests;
    }
  );
}

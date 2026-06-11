# Option-level test checks — generated from the oci.optionTests catalog.
#
# The catalog is populated by nix/modules/oci/testing/option-tests.nix
# (dendritic, auto-discovered by import-tree). Each option file contributes
# its test spec via config._tests; the catalog materializes them as
# read-only, documented entries under oci.optionTests.
#
# This collector generates two checks per option test:
#   - option-<name>          eval-level check (default + override containers)
#   - option-test-coverage   reports options without tests
#
# Run:
#   nix build .#checks.x86_64-linux.option-ports -L
#   nix build .#checks.x86_64-linux.option-test-coverage -L
{ lib, ... }:
{
  perSystem =
    {
      pkgs,
      config,
      ...
    }:
    let
      # Read from the public, read-only catalog (populated by option-tests.nix).
      allTests = config.oci.optionTests;

      # Retrieve collected modules for standalone container evaluation.
      collectedModules = config.oci.perContainer._collectedModules;

      # Evaluate a standalone container with a given config.
      mkContainerEval =
        testName: variant: containerConfig:
        (lib.evalModules {
          modules = collectedModules ++ [
            { config = containerConfig; }
          ];
          specialArgs = {
            name = "test-${testName}-${variant}";
            inherit (pkgs) system;
            inherit pkgs;
            globalConfig = { };
            perSystemConfig = config;
          };
        }).config;

      # Force deep evaluation of container config to catch errors at eval time.
      forceEval =
        containerCfg:
        builtins.seq (builtins.toJSON {
          inherit (containerCfg) _containerName;
          ports = containerCfg.ports or [ ];
          environment = containerCfg.environment or { };
          stopSignal = containerCfg.stopSignal or null;
          package =
            if containerCfg.package or null != null then builtins.typeOf containerCfg.package else "null";
        }) true;

      # Generate a check derivation for a single option test.
      mkCheck =
        testName: spec:
        let
          defaultCfg = mkContainerEval testName "default" spec.default;
          overrideCfg = mkContainerEval testName "override" spec.override;
          evalOk = builtins.seq (forceEval defaultCfg) (builtins.seq (forceEval overrideCfg) true);
        in
        assert evalOk;
        pkgs.runCommand "option-test-${testName}" { } ''
          echo "option test '${testName}' passed (level: ${spec.level})"
          echo "  default container: test-${testName}-default"
          echo "  override container: test-${testName}-override"
          touch $out
        '';

      # Coverage reporting.
      optionDir = ../../nix/modules/oci/containers/_options;
      optionFileList = lib.pipe (lib.filesystem.listFilesRecursive optionDir) [
        (builtins.filter (f: lib.hasSuffix ".nix" (toString f)))
        (map (
          f:
          lib.pipe (toString f) [
            (lib.removePrefix (toString optionDir + "/"))
            (lib.removeSuffix ".nix")
          ]
        ))
      ];
      testedOptions = builtins.attrNames allTests;
      untestedOptions = builtins.filter (f: !(builtins.elem f testedOptions)) optionFileList;
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux (
        (lib.mapAttrs' (name: spec: {
          name = "option-${name}";
          value = mkCheck name spec;
        }) allTests)
        // {
          option-test-coverage = pkgs.runCommand "option-test-coverage" { } (
            if untestedOptions == [ ] then
              ''
                echo "All ${toString (builtins.length optionFileList)} option files have tests."
                touch $out
              ''
            else
              ''
                echo "Options without tests (${toString (builtins.length untestedOptions)} / ${toString (builtins.length optionFileList)}):"
                ${lib.concatMapStringsSep "\n" (o: "echo '  - ${o}'") untestedOptions}
                touch $out
              ''
          );
        }
      );
    };
}

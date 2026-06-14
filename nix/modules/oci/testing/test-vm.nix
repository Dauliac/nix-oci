# BDD VM test builder.
#
# Collects all non-eval test specs (build/inspect/runtime/deploy),
# builds containers as VM dependencies, and generates a NixOS VM test.
#
# Uses options.perSystem for internal option declarations and
# config.perSystem for check generation (can't mix in one block).
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  nixosModule = config.flake.modules.nixos.nix-oci or null;
  nixosTestModule = config.flake.modules.nixos.nix-oci-test or null;
  pythonGen = import ./_python-gen.nix { inherit lib; };

  # Helper to extract VM specs from the collected test specs
  extractVmSpecs =
    allSpecs:
    lib.concatMapAttrs (
      group: scenarios:
      lib.concatMapAttrs (
        name: spec: if spec.level != "eval" then { "${group}--${name}" = spec; } else { }
      ) scenarios
    ) allSpecs;
in
{
  # Internal options for extracted data
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, ... }:
    let
      vmSpecs = extractVmSpecs (config.test.oci.perContainer or { });
    in
    {
      options.test.oci._vmContainers = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        internal = true;
        readOnly = true;
        default = lib.mapAttrs (_: spec: spec.container) vmSpecs;
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
      };
    }
  );

  # VM check generation
  config.perSystem =
    {
      config,
      pkgs,
      lib,
      system,
      ...
    }:
    let
      testHelpers = import ../../../../tests/lib.nix { inherit pkgs lib; };
      canBuildTest = nixosModule != null && nixosTestModule != null && pkgs.stdenv.isLinux;

      vmSpecs = extractVmSpecs (config.test.oci.perContainer or { });
      hasVmSpecs = vmSpecs != { };
      vmContainers = lib.mapAttrs (_: spec: spec.container) vmSpecs;

      runtimeSpecs = lib.filterAttrs (_: s: s.level == "runtime") vmSpecs;
      deploySpecs = lib.filterAttrs (_: s: s.level == "deploy") vmSpecs;
      hasRuntimeOrDeploy = runtimeSpecs != { } || deploySpecs != { };

      pytestCode = lib.concatMapStringsSep "\n\n" (
        name:
        let
          spec = vmSpecs.${name};
        in
        pythonGen.mkPytestFunction {
          containerName = name;
          inherit (spec) assertions;
          given = spec.given or "";
          "when" = spec."when" or "";
          "then" = spec."then" or "";
        }
      ) (lib.attrNames (runtimeSpecs // deploySpecs));

      testSuiteFile = pkgs.writeText "test_bdd_vm.py" ''
        import docker
        import pytest

        @pytest.fixture
        def client():
            return docker.from_env()

        ${pytestCode}
      '';
    in
    {
      checks = lib.optionalAttrs (canBuildTest && hasVmSpecs) {
        bdd-vm = testHelpers.mkVMTest {
          name = "nix-oci-bdd-vm";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [
                nixosModule
                nixosTestModule
              ];

              testing.enable = true;

              oci = {
                enable = true;
                backend = "podman";
                containers = vmContainers;
              };

              environment.systemPackages = [
                (pkgs.python3.withPackages (
                  ps: with ps; [
                    docker
                    pytest
                    requests
                  ]
                ))
              ];
            };

          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("podman.socket")

            # Wait for all container images to be loaded
            ${lib.concatMapStringsSep "\n" (name: ''machine.wait_for_unit("oci-load-${name}.service")'') (
              lib.attrNames vmContainers
            )}

            ${lib.optionalString hasRuntimeOrDeploy ''
              # Copy test suite and run pytest
              machine.copy_from_host("${testSuiteFile}", "/tmp/test_bdd_vm.py")
              machine.succeed(
                  "cd /tmp && DOCKER_HOST=unix:///run/podman/podman.sock "
                  "pytest test_bdd_vm.py -v --tb=short 2>&1"
              )
            ''}
          '';
        };
      };
    };
}

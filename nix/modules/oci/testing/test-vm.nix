# BDD VM test builder.
#
# Collects all non-eval test specs, assembles a NixOS VM test that
# builds containers (as VM dependencies) and runs Python assertions.
#
# Gate stamps are NOT wired yet — they require the full build pipeline
# (nix2container + all flake inputs) which isn't available when
# containers are defined inside VM node configs. The gate will be
# wired once containers are defined at perSystem level with proper
# flake input propagation (future work).
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
  # Internal options
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
      inspectSpecs = lib.filterAttrs (_: s: s.level == "inspect") vmSpecs;
      runtimeSpecs = lib.filterAttrs (_: s: s.level == "runtime") vmSpecs;
      deploySpecs = lib.filterAttrs (_: s: s.level == "deploy") vmSpecs;

      # Only containers that need to RUN go into oci.containers (runtime/deploy).
      # Build-only: built as Nix derivation deps (no podman needed).
      # Inspect: checked by conftest on image.json (no podman needed).
      loadableSpecs = runtimeSpecs // deploySpecs;
      vmContainers = lib.mapAttrs (
        _name: spec:
        spec.container
        // lib.optionalAttrs (spec.level == "runtime") {
          autoStart = true;
          mode = "oneshot";
        }
        // lib.optionalAttrs (spec.level == "deploy") {
          autoStart = true;
          mode = "daemon";
        }
      ) loadableSpecs;
      containerNames = lib.attrNames vmContainers;
      testableSpecs = runtimeSpecs // deploySpecs;
      hasTestableSpecs = testableSpecs != { };

      # Generate pytest code for runtime + deploy specs only
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
      ) (lib.attrNames testableSpecs);

      testSuiteFile = pkgs.writeText "test_bdd_vm.py" ''
        import docker
        import json
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
                # Test defaults via perContainer
                perContainer = [
                  (
                    { lib, ... }:
                    {
                      config.layerStrategy = lib.mkDefault "fine-grained";
                      config.optimizeLayers = lib.mkDefault true;
                    }
                  )
                ];
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
            ${lib.concatMapStringsSep "\n" (
              name: ''machine.wait_for_unit("oci-load-${name}.service")''
            ) containerNames}

            # Wait for runtime/deploy container services to complete/start
            ${lib.concatMapStringsSep "\n" (name: ''machine.wait_for_unit("podman-${name}.service")'') (
              lib.attrNames (runtimeSpecs // deploySpecs)
            )}

            ${lib.optionalString hasTestableSpecs ''
              # Run pytest with inspect + runtime + deploy assertions
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

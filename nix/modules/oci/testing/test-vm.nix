# BDD VM test builder with policy gates.
#
# Collects all non-eval test specs, defines containers at perSystem
# level (triggers image build + policy runner infrastructure),
# builds gate stamps, and assembles a NixOS VM test.
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

  # VM check generation + container definitions + gate stamps
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
      ociLib = config.lib.oci or { };
      hasOciLib = ociLib != { };
      canBuildTest = nixosModule != null && nixosTestModule != null && pkgs.stdenv.isLinux;

      vmSpecs = extractVmSpecs (config.test.oci.perContainer or { });
      hasVmSpecs = vmSpecs != { };
      vmContainers = lib.mapAttrs (_: spec: spec.container) vmSpecs;
      containerNames = lib.attrNames vmContainers;

      runtimeSpecs = lib.filterAttrs (_: s: s.level == "runtime") vmSpecs;
      deploySpecs = lib.filterAttrs (_: s: s.level == "deploy") vmSpecs;
      hasRuntimeOrDeploy = runtimeSpecs != { } || deploySpecs != { };

      # Build gate stamps per container using registered policy runners
      runners = config.oci.internal.policyRunners or { };
      enabledPureRunners = lib.filterAttrs (
        _: r: r.enabled && r.tier == "pure" && r.mkStamp != null
      ) runners;

      gateStampsPerContainer = lib.genAttrs containerNames (
        containerId:
        lib.mapAttrsToList (
          runnerName: runner:
          let
            tried = builtins.tryEval (runner.mkStamp { inherit containerId; });
          in
          if tried.success then tried.value else null
        ) enabledPureRunners
      );

      # Filter out nulls (failed stamps — container may not have the tool enabled)
      cleanGateStamps = lib.mapAttrs (_: stamps: lib.filter (s: s != null) stamps) gateStampsPerContainer;

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
      # Define test containers at perSystem level so policy runners can see them
      oci.containers = lib.mkIf hasVmSpecs vmContainers;

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

              testing = {
                enable = true;
                # Pass gate stamps to NixOS module
                policyGate.stamps = cleanGateStamps;
              };

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

            # Wait for gate + load services
            ${lib.concatMapStringsSep "\n" (
              name: ''machine.wait_for_unit("oci-load-${name}.service")''
            ) containerNames}

            ${lib.optionalString hasRuntimeOrDeploy ''
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

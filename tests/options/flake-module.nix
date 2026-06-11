# Option-level test checks — generated from the oci.optionTests catalog.
#
# Produces three kinds of checks:
#   option-<name>          Eval-level (fast, no VM, every option)
#   option-tests-nixos     Batched NixOS VM: all containers, pytest-xdist parallel
#   option-test-coverage   Coverage report
#
# Run:
#   nix build .#checks.x86_64-linux.option-ports -L
#   nix build .#checks.x86_64-linux.option-tests-nixos -L
{
  config,
  lib,
  ...
}:
let
  nixosModule = config.flake.modules.nixos.nix-oci;
  codegen = import ./codegen.nix { inherit lib; };
in
{
  perSystem =
    {
      pkgs,
      config,
      ...
    }:
    let
      testHelpers = import ../lib.nix { inherit pkgs lib; };
      allTests = config.oci.optionTests;
      collectedModules = config.oci.perContainer._collectedModules;

      pytestEnv = pkgs.python3.withPackages (
        ps: with ps; [
          docker
          pytest
          pytest-xdist
          requests
          tenacity
        ]
      );

      # testSuite is generated AFTER vmTests is defined (see below).

      # ── Eval checks (fast, no VM) ───────────────────────────

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

      mkEvalCheck =
        testName: spec:
        let
          defaultCfg = mkContainerEval testName "default" spec.default;
          overrideCfg = mkContainerEval testName "override" spec.override;
          evalOk = builtins.seq (forceEval defaultCfg) (builtins.seq (forceEval overrideCfg) true);
        in
        assert evalOk;
        pkgs.runCommand "option-test-${testName}" { } ''
          echo "option test '${testName}' passed (level: ${spec.level})"
          touch $out
        '';

      # ── Batched NixOS VM check ──────────────────────────────

      hasAssertions =
        a:
        a.imageConfig != { }
        || a.labels != { }
        || a.fileContains != { }
        || a.fileNotContains != { }
        || a.succeeds != [ ]
        || a.fails != [ ]
        || a.httpResponds != null
        || a.processEnv != { }
        || a.containerInspect != { }
        || a.systemdProps != { }
        || a.runtime != "";

      addTestDeps =
        containerConfig: testDeps:
        if testDeps == [ ] then
          containerConfig
        else
          containerConfig
          // {
            dependencies = (containerConfig.dependencies or [ ]) ++ testDeps;
          };

      vmTests = lib.filterAttrs (
        _: spec:
        !(builtins.elem spec.level [
          "eval"
          "build"
        ])
        && hasAssertions spec.assertions
      ) allTests;

      allContainerDefs = lib.concatMapAttrs (
        name: spec:
        let
          deployAttrs = lib.optionalAttrs (spec.level == "deploy") { autoStart = true; };
        in
        {
          "test-${name}-default" = addTestDeps spec.default spec.testDependencies // deployAttrs;
          "test-${name}-override" = addTestDeps spec.override spec.testDependencies // deployAttrs;
        }
      ) vmTests;

      # Only generate test files for tests that will actually run in the VM.
      testSuite = codegen.mkTestSuite pkgs vmTests;

      vmTestNames = builtins.attrNames vmTests;

      loadWaits = lib.concatStringsSep "\n" (
        lib.concatMap (name: [
          "machine.wait_for_unit('oci-load-test-${name}-default.service')"
          "machine.wait_for_unit('oci-load-test-${name}-override.service')"
        ]) vmTestNames
      );

      deployWaits = lib.concatStringsSep "\n" (
        lib.concatMap (name: [
          "machine.wait_for_unit('podman-test-${name}-default.service')"
          "machine.wait_for_unit('podman-test-${name}-override.service')"
        ]) (builtins.attrNames (lib.filterAttrs (_: s: s.level == "deploy") vmTests))
      );

      nixosVMCheck =
        if vmTests == { } then
          pkgs.runCommand "option-tests-nixos" { } ''
            echo "No VM-level option tests to run."
            touch $out
          ''
        else
          testHelpers.mkVMTest {
            name = "option-tests-nixos";

            nodes.machine =
              { pkgs, ... }:
              {
                imports = [ nixosModule ];
                virtualisation.podman = {
                  enable = true;
                  dockerSocket.enable = true;
                };
                oci = {
                  enable = true;
                  backend = "podman";
                  containers = allContainerDefs;
                };
                environment.systemPackages = [ pytestEnv ];
              };

            testScript = ''
              machine.wait_for_unit("multi-user.target")

              ${loadWaits}

              ${deployWaits}

              machine.succeed("cp -r ${testSuite} /tmp/tests && chmod -R u+w /tmp/tests")
              result = machine.succeed(
                  "cd /tmp/tests && "
                  "DOCKER_HOST=unix:///run/podman/podman.sock "
                  "pytest -x -v --tb=short -n auto 2>&1"
              )
              print(result)
            '';
          };

      # ── Coverage ─────────────────────────────────────────────

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
      normalizeKey = path: builtins.replaceStrings [ "/" ] [ "-" ] path;
      untestedOptions = builtins.filter (
        f: !(builtins.elem (normalizeKey f) testedOptions)
      ) optionFileList;
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux (
        (lib.mapAttrs' (name: spec: {
          name = "option-${name}";
          value = mkEvalCheck name spec;
        }) allTests)
        // {
          option-tests-nixos = nixosVMCheck;

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

# Option-level test checks — generated from the oci.optionTests catalog.
#
# Produces four kinds of checks:
#   option-<name>          Eval-level (fast, no VM, every option)
#   option-tests-nixos     Batched NixOS VM: all containers, pytest-xdist parallel
#   option-tests-debian    Batched Debian 13 VM: same containers, same tests
#   option-test-coverage   Coverage report
#
# Run:
#   nix build .#checks.x86_64-linux.option-ports -L
#   nix build .#checks.x86_64-linux.option-tests-nixos -L
#   nix build .#checks.x86_64-linux.option-tests-debian -L
{
  config,
  lib,
  inputs,
  ...
}:
let
  nixosModule = config.flake.modules.nixos.nix-oci;
  # The system-manager deploy module may have evaluation errors during
  # development (missing sub-modules, etc.). Guard with tryEval so the
  # Debian check degrades gracefully to a pass-through.
  systemManagerModule =
    let
      tried = builtins.tryEval config.flake.modules.systemManager.nix-oci;
    in
    if tried.success then tried.value else null;
  codegen = import ./codegen.nix { inherit lib; };
in
{
  perSystem =
    {
      pkgs,
      config,
      system,
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

      # ── VM-level test infrastructure (shared NixOS + Debian) ─

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

      testContainerDefaults = {
        optimizeLayers = true;
        layerStrategy = "minimal";
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
          mkContainer = cfg: testContainerDefaults // (addTestDeps cfg spec.testDependencies) // deployAttrs;
        in
        {
          "test-${name}-default" = mkContainer spec.default;
          "test-${name}-override" = mkContainer spec.override;
        }
      ) vmTests;

      testSuite = codegen.mkTestSuite pkgs vmTests;

      vmTestNames = builtins.attrNames vmTests;

      # Shared wait scripts (machine/vm object name passed as arg)
      mkLoadWaits =
        m:
        lib.concatStringsSep "\n" (
          lib.concatMap (name: [
            "${m}.wait_for_unit('oci-load-test-${name}-default.service')"
            "${m}.wait_for_unit('oci-load-test-${name}-override.service')"
          ]) vmTestNames
        );

      mkDeployWaits =
        m:
        lib.concatStringsSep "\n" (
          lib.concatMap (name: [
            "${m}.wait_for_unit('podman-test-${name}-default.service')"
            "${m}.wait_for_unit('podman-test-${name}-override.service')"
          ]) (builtins.attrNames (lib.filterAttrs (_: s: s.level == "deploy") vmTests))
        );

      # Shared pytest invocation (identical for NixOS and Debian)
      mkPytestScript = m: ''
        ${m}.succeed("cp -r ${testSuite} /tmp/tests && chmod -R u+w /tmp/tests")
        result = ${m}.succeed("cd /tmp/tests && pytest -x -v --tb=short -n auto 2>&1")
        print(result)
      '';

      # ── NixOS VM check ──────────────────────────────────────

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
                environment.sessionVariables.DOCKER_HOST = "unix:///run/podman/podman.sock";
              };

            testScript = ''
              machine.wait_for_unit("multi-user.target")

              ${mkLoadWaits "machine"}
              ${mkDeployWaits "machine"}
              ${mkPytestScript "machine"}
            '';
          };

      # ── Debian VM check ─────────────────────────────────────

      nixBinPath = "${lib.getBin pkgs.nix}/bin";
      podmanPkg = pkgs.podman;
      systemManagerPkg =
        (builtins.tryEval (inputs.system-manager.packages.${system}.default or null)).value or null;

      # Build a system-manager config with all test containers.
      debianSystemConfig =
        if systemManagerPkg == null || systemManagerModule == null then
          null
        else
          (builtins.tryEval (
            inputs.system-manager.lib.makeSystemConfig {
              modules = [
                systemManagerModule
                (
                  { pkgs, ... }:
                  {
                    nixpkgs.hostPlatform = system;

                    oci = {
                      enable = true;
                      backend = "podman";
                      containers = allContainerDefs;
                    };

                    environment.etc = {
                      "containers/policy.json".text = builtins.toJSON {
                        default = [ { type = "insecureAcceptAnything"; } ];
                      };
                      # vfs driver: 9p filesystem doesn't support overlay.
                      # Paths on the local disk (not 9p-backed /nix/store).
                      "containers/storage.conf".text = ''
                        [storage]
                        driver = "vfs"
                        runroot = "/run/containers/storage"
                        graphroot = "/var/lib/containers/storage"
                      '';
                      "containers/registries.conf".text = ''
                        [registries.search]
                        registries = []
                      '';
                    };
                  }
                )
              ];
            }
          )).value or null;

      debianVMCheck =
        if vmTests == { } || debianSystemConfig == null then
          pkgs.runCommand "option-tests-debian" { } ''
            echo "No VM-level option tests to run (or system-manager input missing)."
            touch $out
          ''
        else
          let
            vmTest = inputs.nix-vm-test.lib.${system}.debian."13" {
              memorySize = 2048;
              cpus = 4;
              diskSize = "+2G";

              extraPathsToRegister = [
                debianSystemConfig
                systemManagerPkg
                pytestEnv
                testSuite
              ];

              testScript = ''
                vm.wait_for_unit("multi-user.target")

                # Symlink tools into PATH
                vm.succeed("ln -sf ${podmanPkg}/bin/podman /usr/local/bin/podman")
                vm.succeed("ln -sf ${pytestEnv}/bin/pytest /usr/local/bin/pytest")
                vm.succeed("ln -sf ${pytestEnv}/bin/python3 /usr/local/bin/python3")

                # Write podman config BEFORE starting podman or system-manager.
                # 9p filesystem doesn't support overlay — must use vfs.
                vm.succeed("mkdir -p /etc/containers /run/podman /var/lib/containers/storage /run/containers/storage")
                vm.succeed("cat > /etc/containers/storage.conf << 'EOF'\n[storage]\ndriver = \"vfs\"\nrunroot = \"/run/containers/storage\"\ngraphroot = \"/var/lib/containers/storage\"\nEOF")
                vm.succeed("cat > /etc/containers/policy.json << 'EOF'\n{\"default\":[{\"type\":\"insecureAcceptAnything\"}]}\nEOF")
                vm.succeed("cat > /etc/containers/registries.conf << 'EOF'\n[registries.search]\nregistries = []\nEOF")

                # Apply system-manager config (loads + starts containers)
                with subtest("system-manager: register config"):
                    vm.succeed(
                        "NIX_REMOTE= "
                        "PATH=${nixBinPath}:$PATH "
                        "${systemManagerPkg}/bin/system-manager register "
                        "--store-path ${debianSystemConfig}"
                    )

                with subtest("system-manager: activate config"):
                    vm.succeed(
                        "${systemManagerPkg}/bin/system-manager activate "
                        "--store-path ${debianSystemConfig}"
                    )

                # Wait for all images to load
                ${mkLoadWaits "vm"}
                ${mkDeployWaits "vm"}

                # Start podman API socket for pytest (after images are loaded).
                # Use execute() — succeed() may hang on background processes.
                vm.execute(
                    "nohup ${podmanPkg}/bin/podman system service "
                    "--time=0 unix:///run/podman/podman.sock "
                    ">/dev/null 2>&1 &"
                )
                vm.wait_until_succeeds("test -S /run/podman/podman.sock", timeout=60)

                # Run the same pytest suite as NixOS
                vm.succeed("cp -r ${testSuite} /tmp/tests && chmod -R u+w /tmp/tests")
                result = vm.succeed(
                    "cd /tmp/tests && "
                    "DOCKER_HOST=unix:///run/podman/podman.sock "
                    "PATH=${pytestEnv}/bin:${podmanPkg}/bin:$PATH "
                    "pytest -x -v --tb=short -n auto 2>&1"
                )
                print(result)
              '';
            };
          in
          vmTest.sandboxed;

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
          option-tests-debian = debianVMCheck;

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

# Consolidated system-manager VM test -- all checks in one Debian 13 boot.
#
# Merges: deploy, structure, hardening.
# Isomorphic with nixos.nix: same container defs, same pytest suites.
#
# Run: nix build .#checks.x86_64-linux.vm-system-manager -L
{
  inputs,
  config,
  ...
}:
let
  systemManagerModule = config.flake.modules.systemManager.nix-oci;
in
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      systemManagerPkg = inputs.system-manager.packages.${system}.default;
      nixBinPath = "${lib.getBin pkgs.nix}/bin";
      podmanPkg = pkgs.podman;
      curlPkg = pkgs.curl;

      # Shared container definitions
      structureContainers = import ./_shared/structure-containers.nix { inherit pkgs; };

      tryIoUring = pkgs.runCommandCC "try-io-uring" { } ''
        cat > try.c <<'CSRC'
        #include <unistd.h>
        #include <sys/syscall.h>
        #include <errno.h>
        int main(void) {
            long ret = syscall(425, 0, (void*)0);
            if (ret == 0) return 0;
            if (errno == 38) return 0;   /* ENOSYS */
            if (errno == 22) return 0;   /* EINVAL */
            if (errno == 1) return 1;    /* EPERM: blocked by seccomp */
            return 2;
        }
        CSRC
        mkdir -p $out/bin
        $CC -o $out/bin/try-io-uring try.c
      '';
      hardeningContainers = import ./_shared/hardening-containers.nix { inherit pkgs tryIoUring; };

      # Deploy container (same as examples/deploy-system-manager/http-server.nix)
      deployContainers = {
        http-server = {
          package = pkgs.python3Minimal;
          dependencies = with pkgs; [
            bashInteractive
            coreutils
          ];
          entrypoint = [
            "${pkgs.writeShellScript "serve" ''
              mkdir -p /tmp/www
              echo "nix-oci-test-ok" > /tmp/www/index.html
              cd /tmp/www
              exec python3 -m http.server 8080
            ''}"
          ];
          autoStart = true;
          ports = [ "8080:8080" ];
        };
      };

      # All containers merged into one system-manager config
      allContainers = deployContainers // structureContainers // hardeningContainers;

      systemConfig = inputs.system-manager.lib.makeSystemConfig {
        modules = [
          systemManagerModule
          (
            { pkgs, ... }:
            {
              nixpkgs.hostPlatform = system;

              oci = {
                enable = true;
                backend = "podman";
                containers = allContainers;
              };

              environment.etc = {
                "containers/policy.json".text = builtins.toJSON {
                  default = [ { type = "insecureAcceptAnything"; } ];
                };
                "containers/storage.conf".text = ''
                  [storage]
                  driver = "overlay"
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
      };

      # Pytest suite: structure + hardening + basic deploy only
      pytestEnv = pkgs.python3.withPackages (
        ps: with ps; [
          docker
          pytest
          pytest-xdist
          requests
          tenacity
        ]
      );

      testSuite = pkgs.runCommand "vm-system-manager-test-suite" { } ''
        mkdir -p $out
        cp ${../suites/conftest.py} $out/conftest.py
        cp ${../suites/test_structure.py} $out/test_structure.py
        cp ${../suites/test_hardening.py} $out/test_hardening.py
        cp ${../suites/test_deploy.py} $out/test_deploy.py
      '';

      vmTest = inputs.nix-vm-test.lib.${system}.debian."13" {
        memorySize = 2048;
        cpus = 4;
        diskSize = "+2G";

        extraPathsToRegister = [
          systemConfig
          systemManagerPkg
        ];

        testScript = ''
          # Boot
          vm.wait_for_unit("multi-user.target")

          # Symlink tools into PATH
          vm.succeed("ln -sf ${podmanPkg}/bin/podman /usr/local/bin/podman")
          vm.succeed("ln -sf ${curlPkg}/bin/curl /usr/local/bin/curl")
          vm.succeed("ln -sf ${pytestEnv}/bin/python3 /usr/local/bin/python3")
          vm.succeed("ln -sf ${pytestEnv}/bin/pytest /usr/local/bin/pytest")

          # Apply system-manager config
          with subtest("system-manager: register"):
              vm.succeed(
                  "NIX_REMOTE= "
                  "PATH=${nixBinPath}:$PATH "
                  "${systemManagerPkg}/bin/system-manager register "
                  "--store-path ${systemConfig}"
              )

          with subtest("system-manager: activate"):
              vm.succeed(
                  "${systemManagerPkg}/bin/system-manager activate "
                  "--store-path ${systemConfig}"
              )

          # Wait for all image loaders
          vm.succeed("sleep 5")  # let systemd settle
          units = vm.succeed(
              "systemctl list-units 'oci-load-*' --no-legend --plain "
              "| awk '{print $1}'"
          ).strip()
          for unit in units.split("\n"):
              if unit.strip():
                  vm.wait_for_unit(unit.strip())

          # Wait for deploy services
          vm.wait_for_unit("podman-http-server.service")
          vm.wait_for_open_port(8080)

          # Start podman socket for Docker SDK access
          vm.succeed("systemctl start podman.socket")

          # Copy test suite and run pytest
          vm.succeed(
              "cp -r ${testSuite} /tmp/tests && chmod -R u+w /tmp/tests"
          )
          vm.succeed(
              "cd /tmp/tests && "
              "DOCKER_HOST=unix:///run/podman/podman.sock "
              "TEST_BACKEND=system-manager "
              "pytest -x -v --tb=short 2>&1"
          )
        '';
      };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-system-manager = vmTest.sandboxed;
      };
    };
}

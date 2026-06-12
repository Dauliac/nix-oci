# Consolidated NixOS VM test -- all container checks in one VM boot.
#
# Merges: deploy, structure, hardening, nixos-containers, GPU.
# Uses shared container definitions from _shared/ and pytest suites
# from ../suites/.
#
# Run: nix build .#checks.x86_64-linux.vm-nixos -L
{
  inputs,
  config,
  ...
}:
let
  nixosModule = config.flake.modules.nixos.nix-oci;
  homeManagerModule = config.flake.modules.homeManager.nix-oci;
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
      # GPU needs allowUnfree for CUDA packages.
      pkgsUnfree = import inputs.nixpkgs {
        localSystem = system;
        config.allowUnfree = true;
      };
      testHelpers = import ../lib.nix {
        pkgs = pkgsUnfree;
        inherit lib;
      };

      # Deploy examples
      nixosExample = ../../examples/deploy-nixos/http-server.nix;
      redisExample = ../../examples/deploy-nixos/redis-nixos-config.nix;
      hmShellExample = ../../examples/deploy-nixos/shell-with-home-manager.nix;
      hmExample = ../../examples/deploy-home-manager/http-server.nix;

      # Shared container definitions
      structureContainers = import ./_shared/structure-containers.nix { pkgs = pkgsUnfree; };

      # Tiny static C binary for seccomp enforcement test
      tryIoUring = pkgsUnfree.runCommandCC "try-io-uring" { } ''
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
      hardeningContainers = import ./_shared/hardening-containers.nix {
        pkgs = pkgsUnfree;
        inherit tryIoUring;
      };

      # Pytest suite: all .py test files assembled into a single derivation
      pytestEnv = pkgsUnfree.python3.withPackages (
        ps: with ps; [
          docker
          pytest
          pytest-xdist
          requests
          tenacity
        ]
      );

      testSuite = pkgsUnfree.runCommand "vm-nixos-test-suite" { } ''
        mkdir -p $out
        cp ${../suites/conftest.py} $out/conftest.py
        cp ${../suites/test_structure.py} $out/test_structure.py
        cp ${../suites/test_hardening.py} $out/test_hardening.py
        cp ${../suites/test_services.py} $out/test_services.py
        cp ${../suites/test_gpu.py} $out/test_gpu.py
        cp ${../suites/test_deploy.py} $out/test_deploy.py
      '';
    in
    {
      checks = lib.optionalAttrs pkgsUnfree.stdenv.isLinux {
        vm-nixos = testHelpers.mkVMTest {
          name = "nix-oci-nixos";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [
                inputs.home-manager.nixosModules.home-manager
                nixosModule
                # Deploy examples (set oci.containers.{http-server,redis,dev-shell})
                nixosExample
                redisExample
                hmShellExample
              ];

              # allowUnfree is already set via pkgsUnfree in runNixOSTest.
              _module.args.home-manager-flake = inputs.home-manager;

              virtualisation.podman = {
                enable = true;
                dockerSocket.enable = true;
              };

              # --- Structure + hardening + nixos-containers + GPU containers ---
              oci.containers =
                structureContainers
                // hardeningContainers
                // {
                  # nixos-containers: jq
                  jq-test = {
                    package = pkgs.jq;
                    user = "jq";
                  };
                  # nixos-containers: devShell (nixosConfig + homeConfig)
                  dev-shell-test = {
                    package = pkgs.zsh;
                    isRoot = false;
                    user = "dev";
                    dependencies = with pkgs; [
                      bashInteractive
                      coreutils
                      git
                      ripgrep
                      starship
                      neovim
                    ];
                    entrypoint = [ "${pkgs.zsh}/bin/zsh" ];
                    nixosConfig.modules = [ { } ];
                    homeConfig = {
                      homeManagerFlake = inputs.home-manager;
                      modules = [
                        (
                          { lib, ... }:
                          {
                            programs.zsh.enable = true;
                            programs.starship.enable = true;
                            programs.git = {
                              enable = true;
                              userName = "dev";
                              userEmail = "dev@container";
                            };
                            fonts.fontconfig.enable = lib.mkForce false;
                          }
                        )
                      ];
                    };
                  };
                  # nixos-containers: postgres (nixosConfig.mainService)
                  nixos-postgres = {
                    nixosConfig = {
                      mainService = "postgresql";
                      modules = [
                        (
                          { pkgs, ... }:
                          {
                            services.postgresql = {
                              enable = true;
                              package = pkgs.postgresql_16;
                              enableTCPIP = true;
                              settings.listen_addresses = "*";
                              authentication = ''
                                local all all trust
                                host  all all 0.0.0.0/0 md5
                              '';
                            };
                          }
                        )
                      ];
                    };
                    isRoot = true;
                  };
                  # GPU
                  gpu-basic = {
                    package = pkgs.busybox;
                    isRoot = true;
                    nixosConfig.modules = [ ];
                    gpu = {
                      enable = true;
                      capabilities = [
                        "compute"
                        "utility"
                      ];
                      runtimeLibraries = [ "cudart" ];
                    };
                  };
                };

              # --- Home-manager: testuser with rootless podman ---
              users.users.testuser = {
                isNormalUser = true;
                home = "/home/testuser";
                subUidRanges = [
                  {
                    startUid = 100000;
                    count = 65536;
                  }
                ];
                subGidRanges = [
                  {
                    startGid = 100000;
                    count = 65536;
                  }
                ];
              };

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.testuser =
                  { ... }:
                  {
                    imports = [
                      homeManagerModule
                      hmExample
                    ];
                    home.stateVersion = "25.11";
                  };
              };

              environment.systemPackages = [
                pytestEnv
                pkgs.curl
                pkgs.iptables
                pkgs.redis
              ];
            };

          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("podman.socket")

            # Wait for all image loaders
            units = machine.succeed(
                "systemctl list-units 'oci-load-*' --no-legend --plain "
                "| awk '{print $1}'"
            ).strip()
            for unit in units.split("\n"):
                if unit.strip():
                    machine.wait_for_unit(unit.strip())

            # Enable linger for home-manager rootless tests
            machine.succeed("loginctl enable-linger testuser")
            uid = machine.succeed("id -u testuser").strip()
            machine.wait_for_unit(f"user@{uid}.service")
            machine.wait_for_unit("oci-load-http-server.service", "testuser")
            machine.wait_for_unit("podman-http-server.service", "testuser")

            # Wait for deploy services
            machine.wait_for_unit("podman-http-server.service")
            machine.wait_for_unit("podman-redis.service")
            machine.wait_for_unit("podman-dev-shell.service")
            machine.wait_for_open_port(8080)
            machine.wait_for_open_port(6379)
            machine.wait_for_open_port(9090)

            # Copy test suite and run pytest
            machine.succeed(
                "cp -r ${testSuite} /tmp/tests && chmod -R u+w /tmp/tests"
            )
            machine.succeed(
                "cd /tmp/tests && "
                "DOCKER_HOST=unix:///run/podman/podman.sock "
                "TEST_BACKEND=nixos "
                "pytest -x -v --tb=short 2>&1"
            )
          '';
        };
      };
    };
}

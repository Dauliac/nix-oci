# Consolidated NixOS VM test -- all container checks in one VM boot.
#
# Merges: deploy, structure, hardening, nixos-containers, GPU.
# Uses shared container definitions and test scripts from _shared/.
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

  # Shared test scripts
  sharedAssertions = import ./_shared/assertions.nix;
  structureTestScript = import ./_shared/structure-test-script.nix;
  hardeningTestScript = import ./_shared/hardening-test-script.nix;
  nixosContainersTestScript = import ./_shared/nixos-containers-test-script.nix;
  gpuTestScript = import ./_shared/gpu-test-script.nix;
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
        $CC -static -o $out try.c
      '';
      hardeningContainers = import ./_shared/hardening-containers.nix {
        pkgs = pkgsUnfree;
        inherit tryIoUring;
      };

      # Python check scripts for deploy tests
      dockerSdkCheck = pkgsUnfree.writeText "check_docker_sdk.py" (
        builtins.readFile ./_python/check_docker_sdk.py
      );
      podmanCliCheck = pkgsUnfree.writeText "check_podman_rootless.py" (
        builtins.readFile ./_python/check_podman_rootless.py
      );
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

              nixpkgs.config.allowUnfree = true;
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

              environment.systemPackages = with pkgs; [
                curl
                iptables
                redis
                (python3.withPackages (ps: [
                  ps.docker
                  ps.urllib3
                ]))
              ];
            };

          testScript = ''
            ${sharedAssertions}
            ${structureTestScript}
            ${hardeningTestScript}
            ${nixosContainersTestScript}
            ${gpuTestScript}

            machine.wait_for_unit("multi-user.target")

            # =================================================================
            # Deploy: http-server (bare package mode)
            # =================================================================

            with subtest("deploy: load service lifecycle"):
                assert_load_service(machine, "http-server")

            with subtest("deploy: container service starts"):
                assert_runner_starts(machine, "http-server")

            with subtest("deploy: runner depends on loader"):
                assert_runner_depends_on_loader(machine, "http-server")

            with subtest("deploy: image present"):
                assert_image_loaded(machine, "http-server")

            with subtest("deploy: firewall allows port 8080"):
                rules = machine.succeed("iptables -L nixos-fw -n")
                assert "8080" in rules, f"Firewall should allow 8080: {rules}"

            with subtest("deploy: HTTP server responds"):
                assert_http_responds(machine, 8080, "nix-oci-test-ok")

            with subtest("deploy: Docker SDK deep inspection"):
                machine.succeed("python3 ${dockerSdkCheck}")

            # =================================================================
            # Deploy: redis (nixosConfig.mainService + sdnotify)
            # =================================================================

            with subtest("deploy-redis: load + start"):
                assert_load_service(machine, "redis")
                assert_runner_starts(machine, "redis")
                assert_runner_depends_on_loader(machine, "redis")
                assert_image_loaded(machine, "redis")

            with subtest("deploy-redis: firewall allows port 6379"):
                rules = machine.succeed("iptables -L nixos-fw -n")
                assert "6379" in rules, f"Firewall should allow 6379: {rules}"

            with subtest("deploy-redis: responds to PING"):
                machine.wait_for_open_port(6379)
                machine.wait_until_succeeds(
                    "redis-cli -h 127.0.0.1 -p 6379 ping", timeout=30
                )
                response = machine.succeed("redis-cli -h 127.0.0.1 -p 6379 ping")
                assert "PONG" in response, f"Expected PONG: {response}"

            with subtest("deploy-redis: sdnotify Type=notify"):
                props = machine.succeed(
                    "systemctl show podman-redis.service "
                    "--property=Type,NotifyAccess"
                )
                assert "Type=notify" in props, f"Expected Type=notify: {props}"
                assert "NotifyAccess=all" in props, f"Expected NotifyAccess=all: {props}"

            with subtest("deploy-redis: stop signal SIGTERM"):
                inspect = machine.succeed("podman inspect redis")
                data = json.loads(inspect)
                sig = data[0].get("Config", {}).get("StopSignal", "")
                assert sig in ("SIGTERM", "15"), f"Expected SIGTERM: {sig}"

            # =================================================================
            # Deploy: dev-shell (homeConfig in deploy)
            # =================================================================

            with subtest("deploy-dev-shell: load + start"):
                assert_load_service(machine, "dev-shell")
                assert_runner_starts(machine, "dev-shell")
                assert_image_loaded(machine, "dev-shell")

            with subtest("deploy-dev-shell: exec works"):
                assert_container_exec(machine, "dev-shell", "echo dev-shell-ok", "dev-shell-ok")

            with subtest("deploy-dev-shell: /home/dev exists"):
                result = machine.succeed("podman exec dev-shell ls -d /home/dev")
                assert "/home/dev" in result, f"Expected /home/dev: {result}"

            # =================================================================
            # Deploy: home-manager (rootless podman)
            # =================================================================

            machine.succeed("loginctl enable-linger testuser")
            uid = machine.succeed("id -u testuser").strip()
            machine.wait_for_unit(f"user@{uid}.service")

            with subtest("hm: load service lifecycle"):
                assert_load_service(machine, "http-server", user="testuser")

            with subtest("hm: runner starts + depends on loader"):
                assert_runner_starts(machine, "http-server", user="testuser")
                assert_runner_depends_on_loader(machine, "http-server", user="testuser")

            with subtest("hm: image loaded"):
                assert_image_loaded(machine, "http-server", user="testuser")

            with subtest("hm: HTTP responds"):
                assert_http_responds(machine, 9090, "nix-oci-test-ok")

            with subtest("hm: podman CLI deep inspection"):
                machine.succeed("su - testuser -c 'python3 ${podmanCliCheck}'")

            # =================================================================
            # Structure tests
            # =================================================================

            run_structure_tests(machine)

            # =================================================================
            # Hardening tests
            # =================================================================

            run_hardening_tests(machine)

            # =================================================================
            # NixOS container tests (jq, devShell, postgres)
            # =================================================================

            run_nixos_containers_tests(machine)

            # =================================================================
            # GPU tests
            # =================================================================

            run_gpu_tests(machine)
          '';
        };
      };
    };
}

# Deploy integration test -- NixOS + home-manager in a single VM.
#
# Boots one NixOS VM that validates:
# - System-level: nix-oci builds+loads image, auto-starts via oci-containers
# - System-level: nixosConfig.mainService with service adapter (redis)
# - User-level:   nix-oci builds+loads image into rootless podman via home-manager
#
# Uses shared assertions from _shared/assertions.nix for DRY with the
# system-manager deploy test (deploy-system-manager.nix).
#
# Run: nix build .#checks.x86_64-linux.vm-deploy-integration -L
{
  inputs,
  config,
  ...
}:
let
  nixosModule = config.flake.modules.nixos.nix-oci;
  homeManagerModule = config.flake.modules.homeManager.nix-oci;
  sharedAssertions = import ./_shared/assertions.nix;
in
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      nixosExample = ../../examples/deploy-nixos/http-server.nix;
      redisExample = ../../examples/deploy-nixos/redis-nixos-config.nix;
      perfExample = ../../examples/deploy-nixos/perf-tuned-server.nix;
      hmShellExample = ../../examples/deploy-nixos/shell-with-home-manager.nix;
      hmExample = ../../examples/deploy-home-manager/http-server.nix;
      dockerSdkCheck = pkgs.writeText "check_docker_sdk.py" (
        builtins.readFile ./_python/check_docker_sdk.py
      );
      podmanCliCheck = pkgs.writeText "check_podman_rootless.py" (
        builtins.readFile ./_python/check_podman_rootless.py
      );
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-deploy-integration = pkgs.testers.runNixOSTest {
          name = "nix-oci-deploy";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [
                inputs.home-manager.nixosModules.home-manager
                nixosModule
                nixosExample
                redisExample
                perfExample
                hmShellExample
              ];

              # Thread home-manager flake into deploy modules for homeConfig
              _module.args.home-manager-flake = inputs.home-manager;

              virtualisation = {
                cores = 4;
                memorySize = 2048;
                diskSize = 4096;
                podman = {
                  enable = true;
                  dockerSocket.enable = true;
                };
              };

              documentation.enable = false;

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

            machine.wait_for_unit("multi-user.target")

            # ===================================================================
            # NixOS system-level tests (http-server -- bare package mode)
            # ===================================================================

            with subtest("nixos: load service lifecycle"):
                assert_load_service(machine, "http-server")

            with subtest("nixos: container service starts"):
                assert_runner_starts(machine, "http-server")

            with subtest("nixos: runner service depends on loader"):
                assert_runner_depends_on_loader(machine, "http-server")

            with subtest("nixos: image present in podman"):
                assert_image_loaded(machine, "http-server")

            with subtest("nixos: firewall allows port 8080"):
                rules = machine.succeed("iptables -L nixos-fw -n")
                assert "8080" in rules, \
                    f"Firewall should allow port 8080: {rules}"

            with subtest("nixos: HTTP server responds"):
                assert_http_responds(machine, 8080, "nix-oci-test-ok")

            with subtest("nixos: Docker SDK deep inspection"):
                machine.succeed("python3 ${dockerSdkCheck}")

            # ===================================================================
            # NixOS system-level tests (redis -- nixosConfig.mainService mode)
            # ===================================================================

            with subtest("nixos-redis: load service lifecycle"):
                assert_load_service(machine, "redis")

            with subtest("nixos-redis: container service starts"):
                assert_runner_starts(machine, "redis")

            with subtest("nixos-redis: runner depends on loader"):
                assert_runner_depends_on_loader(machine, "redis")

            with subtest("nixos-redis: image present in podman"):
                assert_image_loaded(machine, "redis")

            with subtest("nixos-redis: firewall allows port 6379"):
                rules = machine.succeed("iptables -L nixos-fw -n")
                assert "6379" in rules, \
                    f"Firewall should allow port 6379: {rules}"

            with subtest("nixos-redis: Redis responds to PING"):
                machine.wait_for_open_port(6379)
                machine.wait_until_succeeds(
                    "redis-cli -h 127.0.0.1 -p 6379 ping", timeout=30
                )
                response = machine.succeed("redis-cli -h 127.0.0.1 -p 6379 ping")
                assert "PONG" in response, f"Expected PONG: {response}"

            with subtest("nixos-redis: sdnotify Type=notify set"):
                props = machine.succeed(
                    "systemctl show podman-redis.service "
                    "--property=Type,NotifyAccess"
                )
                assert "Type=notify" in props, \
                    f"Expected Type=notify for healthcheck sdnotify: {props}"
                assert "NotifyAccess=all" in props, \
                    f"Expected NotifyAccess=all for healthcheck sdnotify: {props}"

            with subtest("nixos-redis: container has stop signal SIGTERM"):
                inspect = machine.succeed("podman inspect redis")
                data = json.loads(inspect)
                stop_signal = data[0].get("Config", {}).get("StopSignal", "")
                assert stop_signal == "SIGTERM" or stop_signal == "15", \
                    f"Expected SIGTERM stop signal: {stop_signal}"

            # ===================================================================
            # NixOS system-level tests (perf-server -- performance module)
            # ===================================================================

            with subtest("perf: load service lifecycle"):
                assert_load_service(machine, "perf-server")

            with subtest("perf: container service starts"):
                assert_runner_starts(machine, "perf-server")

            with subtest("perf: image present in podman"):
                assert_image_loaded(machine, "perf-server")

            with subtest("perf: HTTP server responds"):
                assert_http_responds(machine, 8081, "nix-oci-perf-ok")

            with subtest("perf: jemalloc LD_PRELOAD in container env"):
                # Read the PID 1 environment inside the container to see
                # OCI-configured env vars (podman exec env may not show them).
                proc_env = machine.succeed(
                    "podman exec perf-server cat /proc/1/environ"
                ).replace("\x00", "\n")
                img_env = [l for l in proc_env.strip().split("\n") if l]
                img_env_str = " ".join(img_env)
                assert "LD_PRELOAD=" in img_env_str and "libjemalloc" in img_env_str, \
                    f"Expected LD_PRELOAD with jemalloc in env: {img_env}"

            with subtest("perf: MALLOC_CONF in env"):
                assert any("MALLOC_CONF=" in e for e in img_env), \
                    f"Expected MALLOC_CONF env var: {img_env}"
                malloc_conf = [e for e in img_env if "MALLOC_CONF=" in e][0]
                assert "muzzy_decay_ms:0" in malloc_conf, \
                    f"Expected muzzy_decay_ms:0 (container safety default): {malloc_conf}"
                assert "narenas:2" in malloc_conf, \
                    f"Expected narenas:2 from allocatorConfig: {malloc_conf}"

            with subtest("perf: GLIBC_TUNABLES in env"):
                assert any("GLIBC_TUNABLES=" in e for e in img_env), \
                    f"Expected GLIBC_TUNABLES env var: {img_env}"
                tunables = [e for e in img_env if "GLIBC_TUNABLES=" in e][0]
                assert "arena_max=4" in tunables, \
                    f"Expected balanced preset arena_max=4: {tunables}"

            with subtest("perf: systemd MemoryHigh property"):
                props = machine.succeed(
                    "systemctl show podman-perf-server.service "
                    "--property=MemoryHigh"
                )
                assert "419430400" in props or "400M" in props, \
                    f"Expected MemoryHigh=400M: {props}"

            with subtest("perf: systemd CPUWeight property"):
                props = machine.succeed(
                    "systemctl show podman-perf-server.service "
                    "--property=CPUWeight"
                )
                assert "200" in props, f"Expected CPUWeight=200: {props}"

            with subtest("perf: systemd OOMScoreAdjust property"):
                props = machine.succeed(
                    "systemctl show podman-perf-server.service "
                    "--property=OOMScoreAdjust"
                )
                assert "-100" in props, f"Expected OOMScoreAdjust=-100: {props}"

            with subtest("perf: container has --log-driver=passthrough"):
                inspect = machine.succeed("podman inspect perf-server")
                data = json.loads(inspect)
                log_driver = data[0].get("HostConfig", {}).get("LogConfig", {}).get("Type", "")
                assert log_driver == "passthrough", \
                    f"Expected log-driver passthrough: {log_driver}"

            with subtest("perf: container has sysctl from web-server preset"):
                inspect = machine.succeed("podman inspect perf-server")
                data = json.loads(inspect)
                sysctls = data[0].get("HostConfig", {}).get("Sysctls", {})
                assert sysctls.get("net.core.somaxconn") == "65535", \
                    f"Expected somaxconn=65535 from web-server preset: {sysctls}"
                assert sysctls.get("net.ipv4.tcp_fastopen") == "3", \
                    f"Expected tcp_fastopen=3 from web-server preset: {sysctls}"

            with subtest("perf: container has tmpfs mount"):
                inspect = machine.succeed("podman inspect perf-server")
                data = json.loads(inspect)
                mounts = data[0].get("Mounts", [])
                tmpfs_dests = [m.get("Destination", "") for m in mounts if m.get("Type") == "tmpfs"]
                assert "/tmp" in tmpfs_dests, \
                    f"Expected /tmp tmpfs mount: {mounts}"

            with subtest("perf: performance OCI labels present"):
                c_inspect = machine.succeed("podman inspect perf-server")
                c_data = json.loads(c_inspect)
                labels = c_data[0].get("Config", {}).get("Labels", {})
                ns = "io.github.dauliac.nix-oci"
                assert labels.get(f"{ns}.performance.enabled") == "true", \
                    f"Expected performance.enabled label: {labels}"
                assert labels.get(f"{ns}.performance.allocator") == "jemalloc", \
                    f"Expected allocator=jemalloc label: {labels}"

            # ===================================================================
            # NixOS system-level tests (dev-shell -- homeConfig in deploy)
            # ===================================================================

            with subtest("nixos-dev-shell: load service lifecycle"):
                assert_load_service(machine, "dev-shell")

            with subtest("nixos-dev-shell: container service starts"):
                assert_runner_starts(machine, "dev-shell")

            with subtest("nixos-dev-shell: image present in podman"):
                assert_image_loaded(machine, "dev-shell")

            with subtest("nixos-dev-shell: container runs and exec works"):
                assert_container_exec(machine, "dev-shell", "echo dev-shell-ok", "dev-shell-ok")

            with subtest("nixos-dev-shell: home directory exists for non-root user"):
                result = machine.succeed(
                    "podman exec dev-shell ls -d /home/dev"
                )
                assert "/home/dev" in result, \
                    f"Expected /home/dev: {result}"

            # ===================================================================
            # Home-manager user-level tests
            # ===================================================================

            machine.succeed("loginctl enable-linger testuser")
            uid = machine.succeed("id -u testuser").strip()
            machine.wait_for_unit(f"user@{uid}.service")

            with subtest("home-manager: load service lifecycle"):
                assert_load_service(machine, "http-server", user="testuser")

            with subtest("home-manager: runner service starts"):
                assert_runner_starts(machine, "http-server", user="testuser")

            with subtest("home-manager: runner service depends on loader"):
                assert_runner_depends_on_loader(machine, "http-server", user="testuser")

            with subtest("home-manager: image loaded in rootless podman"):
                assert_image_loaded(machine, "http-server", user="testuser")

            with subtest("home-manager: container runs and serves HTTP"):
                assert_http_responds(machine, 9090, "nix-oci-test-ok")

            with subtest("home-manager: podman CLI deep inspection"):
                machine.succeed(
                    "su - testuser -c 'python3 ${podmanCliCheck}'"
                )
          '';
        };
      };
    };
}

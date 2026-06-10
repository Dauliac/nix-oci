# Deploy integration test -- NixOS + home-manager in a single VM.
#
# Boots one NixOS VM that validates:
# - System-level: nix-oci builds+loads image, auto-starts via oci-containers
# - System-level: nixosConfig.mainService with service adapter (redis)
# - User-level:   nix-oci builds+loads image into rootless podman via home-manager
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
            import json

            machine.wait_for_unit("multi-user.target")

            # ===================================================================
            # NixOS system-level tests (http-server -- bare package mode)
            # ===================================================================

            with subtest("nixos: load service completes"):
                machine.wait_for_unit("oci-load-http-server.service")

            with subtest("nixos: load service is oneshot with RemainAfterExit"):
                props = machine.succeed(
                    "systemctl show oci-load-http-server.service "
                    "--property=Type,RemainAfterExit,ActiveState"
                )
                assert "Type=oneshot" in props, f"Expected Type=oneshot: {props}"
                assert "RemainAfterExit=yes" in props, f"Expected RemainAfterExit=yes: {props}"
                assert "ActiveState=active" in props, f"Expected ActiveState=active: {props}"

            with subtest("nixos: container service starts"):
                machine.wait_for_unit("podman-http-server.service")

            with subtest("nixos: runner service depends on loader"):
                deps = machine.succeed(
                    "systemctl show podman-http-server.service "
                    "--property=After,Requires"
                )
                assert "oci-load-http-server.service" in deps, \
                    f"Runner must depend on loader: {deps}"

            with subtest("nixos: image present in podman"):
                images_json = machine.succeed("podman images --format json")
                images = json.loads(images_json)
                names = []
                for img in images:
                    for key in ("Names", "names", "RepoTags"):
                        if key in img and img[key]:
                            names.extend(img[key])
                assert any("http-server" in n for n in names), \
                    f"http-server image not found: {names}"

            with subtest("nixos: firewall allows port 8080"):
                rules = machine.succeed("iptables -L nixos-fw -n")
                assert "8080" in rules, \
                    f"Firewall should allow port 8080: {rules}"

            with subtest("nixos: HTTP server responds"):
                machine.wait_for_open_port(8080)
                machine.wait_until_succeeds(
                    "curl -sf http://localhost:8080/index.html", timeout=30
                )
                response = machine.succeed("curl -sf http://localhost:8080/index.html")
                assert "nix-oci-test-ok" in response, f"Bad response: {response}"

            with subtest("nixos: Docker SDK deep inspection"):
                machine.succeed("python3 ${dockerSdkCheck}")

            # ===================================================================
            # NixOS system-level tests (redis -- nixosConfig.mainService mode)
            # ===================================================================

            with subtest("nixos-redis: load service completes"):
                machine.wait_for_unit("oci-load-redis.service")

            with subtest("nixos-redis: container service starts"):
                machine.wait_for_unit("podman-redis.service")

            with subtest("nixos-redis: runner depends on loader"):
                deps = machine.succeed(
                    "systemctl show podman-redis.service "
                    "--property=After,Requires"
                )
                assert "oci-load-redis.service" in deps, \
                    f"Runner must depend on loader: {deps}"

            with subtest("nixos-redis: image present in podman"):
                images_json = machine.succeed("podman images --format json")
                images = json.loads(images_json)
                names = []
                for img in images:
                    for key in ("Names", "names", "RepoTags"):
                        if key in img and img[key]:
                            names.extend(img[key])
                assert any("redis" in n for n in names), \
                    f"redis image not found: {names}"

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
            # NixOS system-level tests (dev-shell -- homeConfig in deploy)
            # ===================================================================

            with subtest("nixos-dev-shell: load service completes"):
                machine.wait_for_unit("oci-load-dev-shell.service")

            with subtest("nixos-dev-shell: container service starts"):
                machine.wait_for_unit("podman-dev-shell.service")

            with subtest("nixos-dev-shell: image present in podman"):
                images_json = machine.succeed("podman images --format json")
                images = json.loads(images_json)
                names = []
                for img in images:
                    for key in ("Names", "names", "RepoTags"):
                        if key in img and img[key]:
                            names.extend(img[key])
                assert any("dev-shell" in n for n in names), \
                    f"dev-shell image not found: {names}"

            with subtest("nixos-dev-shell: container runs and exec works"):
                result = machine.succeed(
                    "podman exec dev-shell echo dev-shell-ok"
                )
                assert "dev-shell-ok" in result, \
                    f"Expected dev-shell-ok: {result}"

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

            with subtest("home-manager: load service completes"):
                machine.wait_for_unit("oci-load-http-server.service", "testuser")

            with subtest("home-manager: load service is oneshot with RemainAfterExit"):
                props = machine.succeed(
                    "su - testuser -c '"
                    "XDG_RUNTIME_DIR=/run/user/$(id -u) "
                    "systemctl --user show oci-load-http-server.service "
                    "--property=Type,RemainAfterExit,ActiveState'"
                )
                assert "Type=oneshot" in props, f"Expected Type=oneshot: {props}"
                assert "RemainAfterExit=yes" in props, f"Expected RemainAfterExit=yes: {props}"
                assert "ActiveState=active" in props, f"Expected ActiveState=active: {props}"

            with subtest("home-manager: runner service starts"):
                machine.wait_for_unit("podman-http-server.service", "testuser")

            with subtest("home-manager: runner service depends on loader"):
                deps = machine.succeed(
                    "su - testuser -c '"
                    "XDG_RUNTIME_DIR=/run/user/$(id -u) "
                    "systemctl --user show podman-http-server.service "
                    "--property=After,Requires'"
                )
                assert "oci-load-http-server.service" in deps, \
                    f"Runner must depend on loader: {deps}"

            with subtest("home-manager: image loaded in rootless podman"):
                images_json = machine.succeed(
                    "su - testuser -c 'podman images --format json'"
                )
                images = json.loads(images_json)
                names = []
                for img in images:
                    for key in ("Names", "names", "RepoTags"):
                        if key in img and img[key]:
                            names.extend(img[key])
                assert any("http-server" in n for n in names), \
                    f"http-server not found: {names}"

            with subtest("home-manager: container runs and serves HTTP"):
                machine.wait_for_open_port(9090)
                machine.wait_until_succeeds(
                    "curl -sf http://localhost:9090/index.html", timeout=30
                )
                response = machine.succeed("curl -sf http://localhost:9090/index.html")
                assert "nix-oci-test-ok" in response, f"Bad response: {response}"

            with subtest("home-manager: podman CLI deep inspection"):
                machine.succeed(
                    "su - testuser -c 'python3 ${podmanCliCheck}'"
                )
          '';
        };
      };
    };
}

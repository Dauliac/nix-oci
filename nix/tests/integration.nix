# Integration tests for nix-oci NixOS and home-manager modules
#
# These tests boot full NixOS VMs with QEMU/KVM and verify that:
# - The NixOS module correctly loads OCI images and starts containers
# - The home-manager module correctly loads OCI images in rootless podman
#
# Run individually:
#   nix build .#checks.x86_64-linux.nixos-module-integration -L
#   nix build .#checks.x86_64-linux.home-manager-module-integration -L
#
# Run all checks:
#   nix flake check -L
{
  inputs,
  config,
  ...
}:
let
  # Use the composed modules from the flake-parts fixed-point.
  # These are defined by nix/modules/deploy/nix-oci/compose.nix and imported
  # at the top-level via nix/module.nix → import-tree ./modules/deploy.
  nixosModule = config.flake.modules.nixos.nix-oci;
  homeManagerModule = config.flake.modules.homeManager.nix-oci;
in
{
  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      nix2container = config.oci.packages.nix2container;

      # --- Shared test image: minimal HTTP server ---
      testEntrypoint = pkgs.writeShellScript "test-serve" ''
        mkdir -p /tmp/www
        echo "nix-oci-test-ok" > /tmp/www/index.html
        cd /tmp/www
        exec ${pkgs.python3Minimal}/bin/python3 -m http.server 8080
      '';

      testImage = nix2container.buildImage {
        name = "test-http-server";
        tag = "test";
        copyToRoot = [
          (pkgs.buildEnv {
            name = "test-root";
            paths = with pkgs; [
              bashInteractive
              coreutils
            ];
            pathsToLink = [ "/bin" ];
          })
        ];
        config = {
          entrypoint = [ "${testEntrypoint}" ];
        };
      };

      # --- Python check scripts (deployed into VMs via nix store) ---

      # Docker SDK script: validates container state via podman's docker-compatible socket
      dockerSdkCheckScript = pkgs.writeText "check_docker_sdk.py" ''
        """
        Validates nix-oci container via Docker SDK connected to podman socket.
        Checks: image presence, container running, exec capability.
        """
        import docker
        import sys

        client = docker.DockerClient(base_url="unix:///run/podman/podman.sock")

        # --- Image checks ---
        images = client.images.list()
        image_tags = [tag for img in images for tag in (img.tags or [])]
        print(f"[docker-sdk] Images: {image_tags}")
        assert any("test-http-server" in tag for tag in image_tags), \
            f"test-http-server image not found in {image_tags}"

        # --- Container checks ---
        containers = client.containers.list()
        names = [c.name for c in containers]
        print(f"[docker-sdk] Running containers: {names}")
        assert any("test-http" in name for name in names), \
            f"test-http container not found in {names}"

        # --- Inspect and exec ---
        for c in containers:
            if "test-http" in c.name:
                assert c.status == "running", f"Container status: {c.status}"
                state = c.attrs.get("State", {})
                print(f"[docker-sdk] Container {c.name}: status={c.status}, pid={state.get('Pid', 'N/A')}")

                exit_code, output = c.exec_run("echo container-exec-ok")
                assert exit_code == 0, f"exec failed with code {exit_code}"
                assert b"container-exec-ok" in output, f"exec output: {output}"
                print("[docker-sdk] Container exec: OK")
                break

        print("[docker-sdk] All checks passed!")
      '';

      # Podman CLI script: validates rootless container state via podman commands
      podmanCliCheckScript = pkgs.writeText "check_podman_rootless.py" ''
        """
        Validates nix-oci container in rootless podman via CLI + JSON parsing.
        Checks: image presence, container running, inspect, exec capability.
        """
        import json
        import subprocess
        import sys

        def run(cmd):
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"FAIL: {cmd}\nstdout: {result.stdout}\nstderr: {result.stderr}", file=sys.stderr)
                sys.exit(1)
            return result.stdout

        # --- Image checks ---
        images = json.loads(run("podman images --format json"))
        image_names = []
        for img in images:
            for key in ("Names", "names", "RepoTags"):
                if key in img and img[key]:
                    image_names.extend(img[key])
        print(f"[podman-cli] Images: {image_names}")
        assert any("test-http-server" in n for n in image_names), \
            f"test-http-server not found in {image_names}"

        # --- Container checks ---
        containers = json.loads(run("podman ps --format json"))
        container_names = []
        for c in containers:
            name = c.get("Names", c.get("Name", ""))
            if isinstance(name, list):
                container_names.extend(name)
            else:
                container_names.append(name)
        print(f"[podman-cli] Running containers: {container_names}")
        assert any("test-http" in n for n in container_names), \
            f"test-http not found in {container_names}"

        # --- Inspect ---
        inspect = json.loads(run("podman inspect test-http"))
        state = inspect[0].get("State", {})
        running = state.get("Running", False) or state.get("Status") == "running"
        assert running, f"Container not running: {state}"
        print(f"[podman-cli] Container test-http: running, pid={state.get('Pid', 'N/A')}")

        # --- Exec ---
        output = run("podman exec test-http echo container-exec-ok")
        assert "container-exec-ok" in output, f"exec output: {output}"
        print("[podman-cli] Container exec: OK")

        print("[podman-cli] All checks passed!")
      '';
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        # =====================================================================
        # Test 1: NixOS module (system-level podman, Docker SDK validation)
        # =====================================================================
        nixos-module-integration = pkgs.testers.runNixOSTest {
          name = "nix-oci-nixos-module";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [ nixosModule ];

              virtualisation = {
                memorySize = 2048;
                diskSize = 4096;
                podman = {
                  enable = true;
                  dockerSocket.enable = true;
                };
              };

              services.nix-oci = {
                enable = true;
                backend = "podman";
                containers.test-http = {
                  image = testImage;
                  autoStart = true;
                };
              };

              virtualisation.oci-containers.containers.test-http = {
                ports = [ "8080:8080" ];
              };

              environment.systemPackages = with pkgs; [
                curl
                (python3.withPackages (ps: [
                  ps.docker
                  ps.urllib3
                ]))
              ];
            };

          testScript = ''
            import json

            machine.wait_for_unit("multi-user.target")

            # --- Phase 1: systemd services ---
            with subtest("nix-oci load service completes successfully"):
                machine.wait_for_unit("nix-oci-load-test-http.service")
                status = machine.succeed(
                    "systemctl status nix-oci-load-test-http.service"
                )
                machine.log(status)

            with subtest("podman container service starts"):
                machine.wait_for_unit("podman-test-http.service")
                status = machine.succeed(
                    "systemctl status podman-test-http.service"
                )
                machine.log(status)

            # --- Phase 2: podman CLI checks ---
            with subtest("image is present in podman"):
                images_json = machine.succeed("podman images --format json")
                images = json.loads(images_json)
                names = []
                for img in images:
                    for key in ("Names", "names", "RepoTags"):
                        if key in img and img[key]:
                            names.extend(img[key])
                machine.log(f"Images: {names}")
                assert any("test-http-server" in n for n in names), \
                    f"test-http-server image not found: {names}"

            with subtest("container is running in podman"):
                ps_json = machine.succeed("podman ps --format json")
                containers = json.loads(ps_json)
                machine.log(f"Containers: {ps_json}")
                assert len(containers) >= 1, "No containers running"

            # --- Phase 3: HTTP connectivity ---
            with subtest("HTTP server responds on port 8080"):
                machine.wait_for_open_port(8080)
                response = machine.succeed("curl -sf http://localhost:8080/index.html")
                assert "nix-oci-test-ok" in response, f"Bad response: {response}"
                machine.log(f"HTTP response OK: {response.strip()}")

            # --- Phase 4: Docker SDK deep inspection ---
            with subtest("Docker SDK validates container via podman socket"):
                machine.succeed("python3 ${dockerSdkCheckScript}")
          '';
        };

        # =====================================================================
        # Test 2: Home-manager module (rootless podman, user systemd services)
        # =====================================================================
        home-manager-module-integration = pkgs.testers.runNixOSTest {
          name = "nix-oci-home-manager-module";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [ inputs.home-manager.nixosModules.home-manager ];

              virtualisation = {
                memorySize = 2048;
                diskSize = 4096;
                podman.enable = true;
              };

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
                    imports = [ homeManagerModule ];

                    services.nix-oci = {
                      enable = true;
                      backend = "podman";
                      containers.test-http = {
                        image = testImage;
                      };
                    };

                    home.stateVersion = "25.11";
                  };
              };

              environment.systemPackages = with pkgs; [
                curl
                python3Minimal
              ];
            };

          testScript = ''
            import json

            machine.wait_for_unit("multi-user.target")

            # Enable linger so user services start without a login session
            machine.succeed("loginctl enable-linger testuser")

            # Wait for user service manager
            uid = machine.succeed("id -u testuser").strip()
            machine.wait_for_unit(f"user@{uid}.service")

            # --- Phase 1: user image loading service ---
            with subtest("user image loading service starts"):
                machine.wait_for_unit("nix-oci-load-test-http.service", "testuser")
                status = machine.succeed(
                    "su - testuser -c 'systemctl --user status nix-oci-load-test-http.service'"
                )
                machine.log(status)

            # --- Phase 2: verify image loaded in rootless podman ---
            with subtest("image loaded in rootless podman"):
                images_json = machine.succeed(
                    "su - testuser -c 'podman images --format json'"
                )
                images = json.loads(images_json)
                names = []
                for img in images:
                    for key in ("Names", "names", "RepoTags"):
                        if key in img and img[key]:
                            names.extend(img[key])
                machine.log(f"User images: {names}")
                assert any("test-http-server" in n for n in names), \
                    f"test-http-server not found: {names}"

            # --- Phase 3: manually run container and verify ---
            with subtest("manually started container works"):
                machine.succeed(
                    "su - testuser -c 'podman run -d --name test-http -p 9090:8080 test-http-server:test'"
                )
                machine.wait_for_open_port(9090)
                response = machine.succeed("curl -sf http://localhost:9090/index.html")
                assert "nix-oci-test-ok" in response, f"Bad response: {response}"
                machine.log(f"HTTP response OK: {response.strip()}")

            # --- Phase 4: rootless podman deep inspection ---
            with subtest("podman CLI validates rootless container"):
                machine.succeed(
                    "su - testuser -c 'python3 ${podmanCliCheckScript}'"
                )
          '';
        };
      };
    };
}

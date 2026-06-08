# Deploy module integration test — NixOS + home-manager in a single VM.
#
# Boots one NixOS VM that validates both:
# - System-level: nix-oci loads image into podman, auto-starts via oci-containers
# - User-level:   nix-oci loads image into rootless podman via home-manager
#
# Run: nix build .#checks.x86_64-linux.deploy-integration -L
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
      config,
      pkgs,
      lib,
      ...
    }:
    let
      nix2container = config.oci.packages.nix2container;
      testImage = import ./_fixtures/test-image.nix { inherit pkgs nix2container; };
      dockerSdkCheck = pkgs.writeText "check_docker_sdk.py" (
        builtins.readFile ./_python/check_docker_sdk.py
      );
      podmanCliCheck = pkgs.writeText "check_podman_rootless.py" (
        builtins.readFile ./_python/check_podman_rootless.py
      );
      nixosExample = import ../../examples/deploy-nixos/http-server.nix { inherit testImage; };
      hmExample = import ../../examples/deploy-home-manager/http-server.nix { inherit testImage; };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        deploy-integration = pkgs.testers.runNixOSTest {
          name = "nix-oci-deploy";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [
                inputs.home-manager.nixosModules.home-manager
                nixosModule
                nixosExample
              ];

              virtualisation = {
                memorySize = 2048;
                diskSize = 4096;
                podman = {
                  enable = true;
                  dockerSocket.enable = true;
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
                python3Minimal
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
            # NixOS system-level tests
            # ===================================================================

            with subtest("nixos: load service completes"):
                machine.wait_for_unit("nix-oci-load-test-http.service")

            with subtest("nixos: container service starts"):
                machine.wait_for_unit("podman-test-http.service")

            with subtest("nixos: image present in podman"):
                images_json = machine.succeed("podman images --format json")
                images = json.loads(images_json)
                names = []
                for img in images:
                    for key in ("Names", "names", "RepoTags"):
                        if key in img and img[key]:
                            names.extend(img[key])
                assert any("test-http-server" in n for n in names), \
                    f"test-http-server not found: {names}"

            with subtest("nixos: HTTP server responds"):
                machine.wait_for_open_port(8080)
                response = machine.succeed("curl -sf http://localhost:8080/index.html")
                assert "nix-oci-test-ok" in response, f"Bad response: {response}"

            with subtest("nixos: Docker SDK deep inspection"):
                machine.succeed("python3 ${dockerSdkCheck}")

            # ===================================================================
            # Home-manager user-level tests
            # ===================================================================

            machine.succeed("loginctl enable-linger testuser")
            uid = machine.succeed("id -u testuser").strip()
            machine.wait_for_unit(f"user@{uid}.service")

            with subtest("home-manager: load service completes"):
                machine.wait_for_unit("nix-oci-load-test-http.service", "testuser")

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
                assert any("test-http-server" in n for n in names), \
                    f"test-http-server not found: {names}"

            with subtest("home-manager: container runs and serves HTTP"):
                machine.succeed(
                    "su - testuser -c 'podman run -d --name test-http -p 9090:8080 test-http-server:test'"
                )
                machine.wait_for_open_port(9090)
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

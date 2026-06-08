# Deploy integration test — NixOS + home-manager in a single VM.
#
# Boots one NixOS VM that validates both:
# - System-level: nix-oci builds+loads image, auto-starts via oci-containers
# - User-level:   nix-oci builds+loads image into rootless podman via home-manager
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
      pkgs,
      lib,
      ...
    }:
    let
      nixosExample = ../../examples/deploy-nixos/http-server.nix;
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
                machine.wait_for_unit("oci-load-http-server.service")

            with subtest("nixos: container service starts"):
                machine.wait_for_unit("podman-http-server.service")

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
                machine.wait_for_unit("oci-load-http-server.service", "testuser")

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
                machine.succeed(
                    "su - testuser -c 'podman run -d --name http-server -p 9090:8080 http-server:latest'"
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

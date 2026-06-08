# NixOS deploy module integration test.
#
# Boots a NixOS VM with podman, loads an OCI image via nix-oci,
# auto-starts it, and validates via HTTP + Docker SDK.
#
# Run: nix build .#checks.x86_64-linux.nixos-module-integration -L
{
  inputs,
  config,
  ...
}:
let
  nixosModule = config.flake.modules.nixos.nix-oci;
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
      dockerSdkCheckScript = pkgs.writeText "check_docker_sdk.py" (
        builtins.readFile ./_python/check_docker_sdk.py
      );
      exampleConfig = import ../../examples/deploy-nixos/http-server.nix { inherit testImage; };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        nixos-module-integration = pkgs.testers.runNixOSTest {
          name = "nix-oci-nixos-module";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [
                nixosModule
                exampleConfig
              ];

              virtualisation = {
                memorySize = 2048;
                diskSize = 4096;
                podman = {
                  enable = true;
                  dockerSocket.enable = true;
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
      };
    };
}

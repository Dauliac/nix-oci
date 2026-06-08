# Home-manager deploy module integration test.
#
# Boots a NixOS VM with a testuser, loads an OCI image into rootless
# podman via home-manager user services, and validates via podman CLI.
#
# Run: nix build .#checks.x86_64-linux.home-manager-module-integration -L
{
  inputs,
  config,
  ...
}:
let
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
      podmanCliCheckScript = pkgs.writeText "check_podman_rootless.py" (
        builtins.readFile ./_python/check_podman_rootless.py
      );
      exampleConfig = import ../../examples/deploy-home-manager/http-server.nix { inherit testImage; };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
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
                    imports = [
                      homeManagerModule
                      exampleConfig
                    ];
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

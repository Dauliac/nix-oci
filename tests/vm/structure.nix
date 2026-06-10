# Image structure test -- validates container contents in a NixOS VM.
#
# Replaces CST (Container Structure Test) YAML tests for basic containers.
# Loads images into podman, then uses `podman run` and `podman image inspect`
# to verify: binaries exist, commands produce expected output, USER is set,
# and dependencies are bundled correctly.
#
# Containers tested:
#   minimalist, minimalistWithDependencies, minimalistWithName,
#   withRootUserAndPackage, write-shell-script-bin, write-shell-application
#
# Run: nix build .#checks.x86_64-linux.vm-structure -L
{ config, ... }:
let
  nixosModule = config.flake.modules.nixos.nix-oci;
in
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      testHelpers = import ../lib.nix { inherit pkgs lib; };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-structure = testHelpers.mkVMTest {
          name = "nix-oci-structure";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [ nixosModule ];

              virtualisation.podman.enable = true;

              oci = {
                enable = true;
                backend = "podman";
                containers = {
                  minimalist = {
                    package = pkgs.kubectl;
                  };
                  minimalistWithDependencies = {
                    package = pkgs.kubectl;
                    dependencies = [
                      pkgs.bash
                      pkgs.kubectl-cnpg
                    ];
                  };
                  minimalistWithName = {
                    name = "hola";
                    package = pkgs.hello;
                  };
                  withRootUserAndPackage = {
                    package = pkgs.bash;
                    dependencies = [ pkgs.coreutils ];
                    isRoot = true;
                  };
                  write-shell-script-bin = {
                    package = pkgs.writeShellScriptBin "hello-script" ''
                      echo "Hello from writeShellScriptBin!"
                    '';
                  };
                  write-shell-application = {
                    package = pkgs.writeShellApplication {
                      name = "hello-app";
                      runtimeInputs = [ pkgs.coreutils ];
                      text = ''
                        echo "Hello from writeShellApplication!"
                        whoami
                      '';
                    };
                  };
                };
              };
            };

          testScript = ''
            import json

            machine.wait_for_unit("multi-user.target")


            def wait_for_load(name):
                """Wait for the oci-load service to complete."""
                machine.wait_for_unit(f"oci-load-{name}.service")


            def image_inspect(image_ref):
                """Return parsed podman image inspect output."""
                raw = machine.succeed(f"podman image inspect {image_ref}")
                return json.loads(raw)[0]


            def assert_env(image_ref, key, value):
                """Assert an environment variable is set in the image config."""
                info = image_inspect(image_ref)
                env_list = info.get("Config", {}).get("Env", [])
                matches = [e for e in env_list if e.startswith(f"{key}=")]
                assert len(matches) == 1, \
                    f"Expected {key}={value} in {image_ref}, got env: {env_list}"
                assert matches[0] == f"{key}={value}", \
                    f"Expected {key}={value}, got {matches[0]}"


            def assert_user(image_ref, expected_user):
                """Assert the image User config matches."""
                info = image_inspect(image_ref)
                user = info.get("Config", {}).get("User", "")
                assert user == expected_user, \
                    f"Expected User={expected_user} in {image_ref}, got: {user}"


            def run_cmd(image_ref, cmd):
                """Run a command in a throwaway container, return stdout."""
                return machine.succeed(f"podman run --rm {image_ref} {cmd}")


            def assert_file_exists(image_ref, path):
                """Assert a file exists inside the image."""
                machine.succeed(f"podman run --rm {image_ref} test -f {path}")


            def assert_cmd_output(image_ref, cmd, expected):
                """Assert command output contains expected string."""
                result = run_cmd(image_ref, cmd)
                assert expected in result, \
                    f"Expected '{expected}' in output of '{cmd}', got: {result}"


            # ===================================================================
            # Load all images
            # ===================================================================

            with subtest("load all images"):
                for name in [
                    "minimalist",
                    "minimalistWithDependencies",
                    "minimalistWithName",
                    "withRootUserAndPackage",
                    "write-shell-script-bin",
                    "write-shell-application",
                ]:
                    wait_for_load(name)

            # ===================================================================
            # minimalist (kubectl)
            # ===================================================================

            with subtest("minimalist: USER is kubectl"):
                assert_env("minimalist:latest", "USER", "kubectl")

            with subtest("minimalist: kubectl binary exists"):
                assert_file_exists("minimalist:latest", "/bin/kubectl")

            with subtest("minimalist: kubectl version runs"):
                run_cmd("minimalist:latest", "kubectl version --client")

            # ===================================================================
            # minimalistWithDependencies (kubectl + bash + kubectl-cnpg)
            # ===================================================================

            with subtest("minimalistWithDependencies: USER is kubectl"):
                assert_env("minimalistWithDependencies:latest", "USER", "kubectl")

            with subtest("minimalistWithDependencies: kubectl binary exists"):
                assert_file_exists("minimalistWithDependencies:latest", "/bin/kubectl")

            with subtest("minimalistWithDependencies: bash binary exists"):
                assert_file_exists("minimalistWithDependencies:latest", "/bin/bash")

            with subtest("minimalistWithDependencies: kubectl runs"):
                run_cmd("minimalistWithDependencies:latest", "kubectl version --client")

            with subtest("minimalistWithDependencies: bash runs"):
                run_cmd("minimalistWithDependencies:latest", "bash --version")

            with subtest("minimalistWithDependencies: kubectl-cnpg runs"):
                run_cmd("minimalistWithDependencies:latest", "kubectl-cnpg version")

            # ===================================================================
            # minimalistWithName (hello, image named "hola")
            # ===================================================================

            with subtest("minimalistWithName: USER is hello"):
                assert_env("hola:latest", "USER", "hello")

            with subtest("minimalistWithName: hello binary exists"):
                assert_file_exists("hola:latest", "/bin/hello")

            with subtest("minimalistWithName: hello runs"):
                run_cmd("hola:latest", "hello")

            # ===================================================================
            # withRootUserAndPackage (bash + coreutils, root user)
            # ===================================================================

            with subtest("withRootUserAndPackage: USER is root"):
                assert_env("withRootUserAndPackage:latest", "USER", "root")

            with subtest("withRootUserAndPackage: bash binary exists"):
                assert_file_exists("withRootUserAndPackage:latest", "/bin/bash")

            with subtest("withRootUserAndPackage: bash runs"):
                run_cmd("withRootUserAndPackage:latest", "bash --version")

            with subtest("withRootUserAndPackage: coreutils ls runs"):
                run_cmd("withRootUserAndPackage:latest", "ls --version")

            with subtest("withRootUserAndPackage: whoami is root"):
                assert_cmd_output("withRootUserAndPackage:latest", "whoami", "root")

            # ===================================================================
            # write-shell-script-bin
            # ===================================================================

            with subtest("write-shell-script-bin: USER is hello-script"):
                assert_env("write-shell-script-bin:latest", "USER", "hello-script")

            with subtest("write-shell-script-bin: binary exists"):
                assert_file_exists("write-shell-script-bin:latest", "/bin/hello-script")

            with subtest("write-shell-script-bin: runs with expected output"):
                assert_cmd_output(
                    "write-shell-script-bin:latest",
                    "hello-script",
                    "Hello from writeShellScriptBin!",
                )

            # ===================================================================
            # write-shell-application
            # ===================================================================

            with subtest("write-shell-application: USER is hello-app"):
                assert_env("write-shell-application:latest", "USER", "hello-app")

            with subtest("write-shell-application: binary exists"):
                assert_file_exists("write-shell-application:latest", "/bin/hello-app")

            with subtest("write-shell-application: runs with expected output"):
                assert_cmd_output(
                    "write-shell-application:latest",
                    "hello-app",
                    "Hello from writeShellApplication!",
                )
          '';
        };
      };
    };
}

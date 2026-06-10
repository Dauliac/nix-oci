# Image structure test -- validates container contents in a NixOS VM.
#
# Replaces CST (Container Structure Test) YAML tests for basic containers.
# Containers are built via the deploy module, loaded into podman, and tested
# with `podman run --entrypoint` and `podman image inspect`.
#
# Validates: binaries run, commands produce expected output, OCI User field,
# dependencies bundled correctly.
#
# Containers tested:
#   minimalist, minimalist-with-deps, minimalist-with-name,
#   with-root-user, write-shell-script-bin, write-shell-application
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
                    user = "kubectl";
                  };
                  minimalist-with-deps = {
                    package = pkgs.kubectl;
                    user = "kubectl";
                    dependencies = [
                      pkgs.bash
                      pkgs.kubectl-cnpg
                    ];
                  };
                  minimalist-with-name = {
                    name = "hola";
                    package = pkgs.hello;
                    user = "hello";
                  };
                  with-root-user = {
                    package = pkgs.bash;
                    dependencies = [ pkgs.coreutils ];
                    isRoot = true;
                  };
                  write-shell-script-bin = {
                    package = pkgs.writeShellScriptBin "hello-script" ''
                      echo "Hello from writeShellScriptBin!"
                    '';
                    user = "hello-script";
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
                    user = "hello-app";
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


            def assert_user(image_ref, expected_user):
                """Assert the OCI User config field matches."""
                info = image_inspect(image_ref)
                user = info.get("Config", {}).get("User", "")
                assert user == expected_user, \
                    f"Expected User={expected_user} in {image_ref}, got: {user}"


            def run_entrypoint(image_ref, binary, args=""):
                """Run a specific binary as entrypoint (works without coreutils)."""
                return machine.succeed(
                    f"podman run --rm --entrypoint '{binary}' {image_ref} {args}"
                )


            def assert_binary_runs(image_ref, binary, args=""):
                """Assert a binary can be executed inside the image."""
                run_entrypoint(image_ref, binary, args)


            def assert_entrypoint_output(image_ref, binary, args, expected):
                """Assert binary output contains expected string."""
                result = run_entrypoint(image_ref, binary, args)
                assert expected in result, \
                    f"Expected '{expected}' in output of '{binary} {args}', got: {result}"


            # ===================================================================
            # Load all images
            # ===================================================================

            with subtest("load all images"):
                for name in [
                    "minimalist",
                    "minimalist-with-deps",
                    "minimalist-with-name",
                    "with-root-user",
                    "write-shell-script-bin",
                    "write-shell-application",
                ]:
                    wait_for_load(name)

            # ===================================================================
            # minimalist (kubectl)
            # ===================================================================

            with subtest("minimalist: User is kubectl"):
                assert_user("minimalist:latest", "kubectl")

            with subtest("minimalist: kubectl runs"):
                assert_binary_runs("minimalist:latest", "/bin/kubectl", "version --client")

            # ===================================================================
            # minimalist-with-deps (kubectl + bash + kubectl-cnpg)
            # ===================================================================

            with subtest("minimalist-with-deps: User is kubectl"):
                assert_user("minimalist-with-deps:latest", "kubectl")

            with subtest("minimalist-with-deps: kubectl runs"):
                assert_binary_runs(
                    "minimalist-with-deps:latest", "/bin/kubectl", "version --client"
                )

            with subtest("minimalist-with-deps: bash runs"):
                assert_binary_runs(
                    "minimalist-with-deps:latest", "/bin/bash", "--version"
                )

            with subtest("minimalist-with-deps: kubectl-cnpg runs"):
                assert_binary_runs(
                    "minimalist-with-deps:latest", "/bin/kubectl-cnpg", "version"
                )

            # ===================================================================
            # minimalist-with-name (hello, image named "hola")
            # ===================================================================

            with subtest("minimalist-with-name: User is hello"):
                assert_user("hola:latest", "hello")

            with subtest("minimalist-with-name: hello runs"):
                assert_binary_runs("hola:latest", "/bin/hello")

            # ===================================================================
            # with-root-user (bash + coreutils, root user)
            # ===================================================================

            with subtest("with-root-user: User is root"):
                assert_user("with-root-user:latest", "root")

            with subtest("with-root-user: bash runs"):
                assert_binary_runs(
                    "with-root-user:latest", "/bin/bash", "--version"
                )

            with subtest("with-root-user: coreutils ls runs"):
                assert_binary_runs(
                    "with-root-user:latest", "/bin/ls", "--version"
                )

            with subtest("with-root-user: whoami is root"):
                assert_entrypoint_output(
                    "with-root-user:latest", "/bin/whoami", "", "root"
                )

            # ===================================================================
            # write-shell-script-bin
            # ===================================================================

            with subtest("write-shell-script-bin: User is hello-script"):
                assert_user("write-shell-script-bin:latest", "hello-script")

            with subtest("write-shell-script-bin: runs with expected output"):
                assert_entrypoint_output(
                    "write-shell-script-bin:latest",
                    "/bin/hello-script",
                    "",
                    "Hello from writeShellScriptBin!",
                )

            # ===================================================================
            # write-shell-application
            # ===================================================================

            with subtest("write-shell-application: User is hello-app"):
                assert_user("write-shell-application:latest", "hello-app")

            with subtest("write-shell-application: runs with expected output"):
                assert_entrypoint_output(
                    "write-shell-application:latest",
                    "/bin/hello-app",
                    "",
                    "Hello from writeShellApplication!",
                )
          '';
        };
      };
    };
}

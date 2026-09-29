# BDD test specs for the system-manager deploy module.
#
# Covers requirement `System-manager deploy runtime` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# The VM harness in `test-vm.nix` is NixOS-only; a real system-manager
# host boot happens in the CI e2e job. These specs sit at level `eval`
# and `build` so `nix eval .#tests --json` verifies the module shape
# without needing a system-manager runtime.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-system-manager = {
        eval-system-manager-module-composes = {
          given = "a system-manager profile that includes nix-oci.modules.systemManager.nix-oci";
          "when" = "the container config is evaluated";
          "then" = "the container config evaluates without error";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
          };
        };

        build-loader-and-runner-services = {
          given = "a system-manager container with a package";
          "when" = "the deploy module composes systemd services";
          "then" = "both oci-load and the podman runner unit build";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
          };
        };
      };
    };
}

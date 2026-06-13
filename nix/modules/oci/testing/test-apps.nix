# Test flake apps by running one app per tool in a NixOS VM.
#
# Defines ONE minimal test container at perSystem level, generates
# all app scripts for it, then runs each unique tool once in the VM.
# One container × one app per tool = ~15 runs (not N×M).
#
# Architecture:
# - test-apps.nix (this file): defines test container + passes apps to VM
# - _test/_apps-config.nix (NixOS module): converts app scripts → systemd oneshots
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  nixosModule = config.flake.modules.nixos.nix-oci or null;
  nixosTestModule = config.flake.modules.nixos.nix-oci-test or null;

  # Unique container ID for app testing — won't collide with user containers
  appTestContainerId = "__bdd-app-test__";
in
{
  config.perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      testHelpers = import ../../../../tests/lib.nix { inherit pkgs lib; };
      canBuildTest = nixosModule != null && nixosTestModule != null && pkgs.stdenv.isLinux;

      # Filter apps for our test container only
      appPrefix = "oci-";
      appSuffix = "-${appTestContainerId}";
      testApps = lib.filterAttrs (name: _: lib.hasPrefix appPrefix name && lib.hasSuffix appSuffix name) (
        config.oci.flake.apps or { }
      );
      hasTestApps = testApps != { };
    in
    {
      # Define ONE minimal test container with all tools enabled
      oci.containers.${appTestContainerId} = {
        package = pkgs.hello;
        user = "nobody";
        entrypoint = [ "${pkgs.hello}/bin/hello" ];
        labels = {
          "org.opencontainers.image.title" = "bdd-app-test";
          "org.opencontainers.image.source" = "https://github.com/Dauliac/nix-oci";
          "org.opencontainers.image.description" = "Minimal container for app testing";
        };
        # Enable all tools so apps get generated
        policy.conftest.enabled = true;
        lint.dockle.enabled = true;
        sbom.syft.enabled = true;
        test.dive.enabled = true;
      };

      checks = lib.optionalAttrs (canBuildTest && hasTestApps) {
        bdd-apps = testHelpers.mkVMTest {
          name = "nix-oci-app-tests";

          nodes.machine =
            { ... }:
            {
              imports = [
                nixosModule
                nixosTestModule
              ];

              testing = {
                enable = true;
                appScripts = testApps;
              };

              oci = {
                enable = true;
                backend = "podman";
                # Only deploy the test container
                containers.${appTestContainerId} = config.oci.containers.${appTestContainerId};
              };
            };

          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("podman.socket")
            machine.wait_for_unit("oci-load-${appTestContainerId}.service")

            # Run each app (one per tool) as systemd oneshot
            ${lib.concatMapStringsSep "\n" (name: ''
              with subtest("${name}"):
                  machine.succeed("systemctl start nix-oci-app-${name}.service")
            '') (lib.attrNames testApps)}
          '';
        };
      };
    };
}

# Test flake apps by running them as systemd services in a NixOS VM.
#
# Uses the FIRST container that has apps generated for it.
# Does NOT define its own container — uses whatever the consuming
# flake defines in oci.containers.
#
# Architecture:
# - test-apps.nix (this file): picks first container's apps, builds VM check
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

      # Use ALL apps from the flake (generated from oci.containers)
      allApps = config.oci.flake.apps or { };
      hasApps = allApps != { };

      # Pick the first container for the VM deploy
      containerNames = lib.attrNames (config.oci.containers or { });
      hasContainers = containerNames != [ ];
      firstContainer = if hasContainers then lib.head containerNames else null;
    in
    {
      checks = lib.optionalAttrs (canBuildTest && hasApps && hasContainers) {
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
                appScripts = allApps;
              };

              oci = {
                enable = true;
                backend = "podman";
                containers.${firstContainer} = config.oci.containers.${firstContainer};
              };
            };

          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("podman.socket")
            machine.wait_for_unit("oci-load-${firstContainer}.service")

            # Run each app as systemd oneshot
            ${lib.concatMapStringsSep "\n" (name: ''
              with subtest("${name}"):
                  machine.succeed("systemctl start nix-oci-app-${name}.service")
            '') (lib.attrNames allApps)}
          '';
        };
      };
    };
}

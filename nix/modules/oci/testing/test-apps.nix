# Test flake apps by running them as systemd services in a NixOS VM.
#
# Defines a test container at the perSystem level (to generate app scripts),
# then passes those scripts to the NixOS test module which wraps them as
# systemd oneshot services. The VM boots, loads the container, and runs
# each app service.
#
# Architecture:
# - test-apps.nix (this file): defines test container + builds VM check
# - _test/_apps-config.nix (NixOS module): converts app scripts → systemd
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
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      testHelpers = import ../../../../tests/lib.nix { inherit pkgs lib; };
      ociLib = config.lib.oci or { };
      hasOciLib = ociLib != { };
      canBuildTest = nixosModule != null && nixosTestModule != null && hasOciLib && pkgs.stdenv.isLinux;

      # We need containers defined at perSystem level to generate app scripts.
      # Check if any containers exist (they come from oci.containers).
      containerNames = lib.attrNames (config.oci.containers or { });
      hasContainers = containerNames != [ ];

      # Pick the first container for app testing (or skip if none)
      testContainerId = if hasContainers then lib.head containerNames else null;

      # Collect app scripts for the test container
      mkAppScripts =
        containerId:
        let
          # Only include apps where the underlying function exists
          tryApp =
            name: fn: args:
            let
              tried = builtins.tryEval (fn args);
            in
            lib.optionalAttrs tried.success { ${name} = tried.value; };
        in
        (tryApp "policy-conftest" ociLib.mkScriptPolicyConftest {
          perSystemConfig = config.oci;
          globalConfig = { };
          inherit containerId;
        })
        // (tryApp "lint-dockle" ociLib.mkScriptLintDockle {
          perSystemConfig = config.oci;
          globalConfig = { };
          inherit containerId;
        })
        // (tryApp "sbom-syft" ociLib.mkScriptSBOMSyft {
          perSystemConfig = config.oci;
          inherit containerId;
        });

      appTestCheck = lib.optionalAttrs (canBuildTest && hasContainers) {
        bdd-apps = testHelpers.mkVMTest {
          name = "nix-oci-app-tests";

          nodes.machine =
            { pkgs, ... }:
            let
              appScripts = mkAppScripts testContainerId;
              # Convert scripts to app format for the NixOS module
              appAttrs = lib.mapAttrs (name: script: {
                type = "app";
                program = "${script}/bin/${name}-${testContainerId}";
              }) appScripts;
            in
            {
              imports = [
                nixosModule
                nixosTestModule
              ];

              testing = {
                enable = true;
                appScripts = appAttrs;
              };

              oci = {
                enable = true;
                backend = "podman";
                containers.${testContainerId} = config.oci.containers.${testContainerId};
              };
            };

          testScript =
            let
              appScripts = mkAppScripts testContainerId;
            in
            ''
              machine.wait_for_unit("multi-user.target")
              machine.wait_for_unit("podman.socket")

              # Wait for container image to be loaded
              machine.wait_for_unit("oci-load-${testContainerId}.service")

              # Run each app as systemd oneshot and verify success
              ${lib.concatMapStringsSep "\n" (name: ''
                with subtest("${name}"):
                    machine.succeed("systemctl start nix-oci-app-${name}.service")
              '') (lib.attrNames appScripts)}
            '';
        };
      };
    in
    {
      checks = appTestCheck;
    }
  );
}

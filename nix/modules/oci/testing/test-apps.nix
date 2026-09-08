# Test flake apps by running them as systemd services in a NixOS VM.
#
# App scripts are self-contained (they use skopeo to load images directly),
# so this VM only needs podman — no oci.containers deploy is required.
#
# Architecture:
# - test-apps.nix (this file): picks apps, builds VM check
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
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { ... }:
    {
      options.test.oci._bddAppsCheck = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        internal = true;
        description = "BDD apps test derivation (set by test-apps.nix, consumed by e2e gate).";
      };
    }
  );

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

      # Use flake apps, but skip:
      #   * `oci-push-*`  -- pushes to a remote registry via skopeo
      #     docker://...; the in-VM docker-registry serves plain HTTP
      #     and skopeo defaults to HTTPS, aborting with:
      #       http: server gave HTTP response to HTTPS client
      #     The BDD VM's `test_registry_push_pipeline` already covers
      #     the push path end-to-end (via `skopeo --dest-tls-verify=false`
      #     in test-vm.nix's dedicated flake-oci-load service).
      #   * `oci-sandbox-*` -- runs the container entrypoint under
      #     bubblewrap. bwrap chdir's into the image's `WorkingDir`,
      #     which for services like caddy is `/var/lib/caddy` -- a
      #     runtime-only path that does not exist in the sandbox
      #     rootfs. The sandbox path is a separate integration surface
      #     from the load-*/push-* smoke tests this VM is meant to
      #     exercise; giving it a real home would require its own
      #     scaffolding.
      allApps = lib.filterAttrs (
        n: _: !(lib.hasPrefix "oci-push-" n) && !(lib.hasPrefix "oci-sandbox-" n)
      ) (config.oci.flake.apps or { });
      hasApps = allApps != { };

      containerNames = lib.attrNames (config.oci.containers or { });
      hasContainers = containerNames != [ ];
    in
    {
      # Internal: derivation stored here, exposed via checks.e2e in the consuming flake.
      test.oci._bddAppsCheck = lib.mkIf (canBuildTest && hasApps && hasContainers) (
        testHelpers.mkVMTest {
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

              # Apps are self-contained (skopeo loads images directly).
              # Only enable podman backend — no oci.containers needed.
              oci = {
                enable = true;
                backend = "podman";
              };
            };

          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("podman.socket")

            # Run each app as systemd oneshot
            ${lib.concatMapStringsSep "\n" (name: ''
              with subtest("${name}"):
                  machine.succeed("systemctl start nix-oci-app-${name}.service")
            '') (lib.attrNames allApps)}
          '';
        }
      );
    };
}

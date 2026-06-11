# Deploy integration test -- system-manager on Debian 13 (non-NixOS).
#
# Boots a Debian 13 VM via nix-vm-test, applies a system-manager config
# that includes nix-oci containers, then validates the same container
# lifecycle as the NixOS deploy test using shared assertions.
#
# The host /nix/store is automatically mounted via 9p+overlay by
# nix-vm-test, so all derivations (podman, images, copy scripts) are
# available without copying or network access.
#
# Uses shared assertions from _shared/assertions.nix (isomorphic with
# the NixOS deploy test in deploy.nix).
#
# Run: nix build .#checks.x86_64-linux.vm-deploy-system-manager -L
{
  inputs,
  config,
  ...
}:
let
  systemManagerModule = config.flake.modules.systemManager.nix-oci;
  sharedAssertions = import ./_shared/assertions.nix;
in
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      smExample = ../../examples/deploy-system-manager/http-server.nix;

      # Pre-build the system-manager configuration at eval time.
      # The resulting derivation contains services.json, etcFiles.json,
      # and activation scripts that system-manager applies in the VM.
      systemConfig = inputs.system-manager.lib.makeSystemConfig {
        modules = [
          systemManagerModule
          smExample
          (
            { pkgs, ... }:
            {
              nixpkgs.hostPlatform = system;

              # Podman runtime config -- system-manager manages /etc files.
              # Without this, podman refuses to pull/load images.
              environment.etc = {
                "containers/policy.json".text = builtins.toJSON {
                  default = [ { type = "insecureAcceptAnything"; } ];
                };
                "containers/storage.conf".text = ''
                  [storage]
                  driver = "overlay"
                  runroot = "/run/containers/storage"
                  graphroot = "/var/lib/containers/storage"
                '';
                "containers/registries.conf".text = ''
                  [registries.search]
                  registries = []
                '';
              };
            }
          )
        ];
      };

      # system-manager CLI binary from the flake input.
      systemManagerPkg = inputs.system-manager.packages.${system}.default;

      # Nix binary for nix-store --load-db (used by nix-vm-test mountStore).
      nixBinPath = "${lib.getBin pkgs.nix}/bin";

      # Tools needed in the VM shell for assertions.
      # Symlinked into /usr/local/bin (in default PATH on Debian).
      podmanPkg = pkgs.podman;
      curlPkg = pkgs.curl;

      # nix-vm-test API: Debian 13 cloud image with 9p + overlay store.
      vmTest = inputs.nix-vm-test.lib.${system}.debian."13" {
        memorySize = 2048;
        cpus = 4;
        diskSize = "+2G";

        # Register closures in the Nix DB so system-manager can find them.
        extraPathsToRegister = [
          systemConfig
          systemManagerPkg
        ];

        testScript = ''
          ${sharedAssertions}

          # Wait for boot (mount-store is a oneshot WantedBy=multi-user.target,
          # so the Nix store is already mounted when multi-user.target is reached)
          vm.wait_for_unit("multi-user.target")

          # Symlink Nix-built tools into /usr/local/bin (in default PATH
          # on Debian). vm.succeed() runs each command in a fresh subshell,
          # so export PATH doesn't persist — symlinks are the reliable way.
          vm.succeed("ln -sf ${podmanPkg}/bin/podman /usr/local/bin/podman")
          vm.succeed("ln -sf ${curlPkg}/bin/curl /usr/local/bin/curl")

          # ===================================================================
          # Apply system-manager config
          # ===================================================================

          with subtest("system-manager: register pre-built config"):
              vm.succeed(
                  "NIX_REMOTE= "
                  "PATH=${nixBinPath}:$PATH "
                  "${systemManagerPkg}/bin/system-manager register "
                  "--store-path ${systemConfig}"
              )

          with subtest("system-manager: activate config"):
              # Activation may log a timeout warning for slow systemd jobs
              # (image loading takes time) but still succeeds.
              vm.succeed(
                  "${systemManagerPkg}/bin/system-manager activate "
                  "--store-path ${systemConfig}"
              )

          # ===================================================================
          # Container lifecycle tests (isomorphic with NixOS deploy test)
          # ===================================================================

          with subtest("system-manager: load service lifecycle"):
              assert_load_service(vm, "http-server")

          with subtest("system-manager: container service starts"):
              assert_runner_starts(vm, "http-server")

          with subtest("system-manager: runner depends on loader"):
              assert_runner_depends_on_loader(vm, "http-server")

          with subtest("system-manager: image present in podman"):
              assert_image_loaded(vm, "http-server")

          with subtest("system-manager: HTTP server responds"):
              assert_http_responds(vm, 8080, "nix-oci-test-ok")

          with subtest("system-manager: container exec works"):
              assert_container_exec(vm, "http-server", "echo exec-ok", "exec-ok")
        '';
      };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-deploy-system-manager = vmTest.sandboxed;
      };
    };
}

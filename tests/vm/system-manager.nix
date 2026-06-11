# Consolidated system-manager VM test -- all checks in one Debian 13 boot.
#
# Merges: deploy, structure, hardening.
# Isomorphic with nixos.nix: same shared assertions, same container defs.
#
# Run: nix build .#checks.x86_64-linux.vm-system-manager -L
{
  inputs,
  config,
  ...
}:
let
  systemManagerModule = config.flake.modules.systemManager.nix-oci;

  # Shared test scripts
  sharedAssertions = import ./_shared/assertions.nix;
  structureTestScript = import ./_shared/structure-test-script.nix;
  hardeningTestScript = import ./_shared/hardening-test-script.nix;
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
      systemManagerPkg = inputs.system-manager.packages.${system}.default;
      nixBinPath = "${lib.getBin pkgs.nix}/bin";
      podmanPkg = pkgs.podman;
      curlPkg = pkgs.curl;

      # Shared container definitions
      structureContainers = import ./_shared/structure-containers.nix { inherit pkgs; };

      tryIoUring = pkgs.runCommandCC "try-io-uring" { } ''
        cat > try.c <<'CSRC'
        #include <unistd.h>
        #include <sys/syscall.h>
        #include <errno.h>
        int main(void) {
            long ret = syscall(425, 0, (void*)0);
            if (ret == 0) return 0;
            if (errno == 38) return 0;   /* ENOSYS */
            if (errno == 22) return 0;   /* EINVAL */
            if (errno == 1) return 1;    /* EPERM: blocked by seccomp */
            return 2;
        }
        CSRC
        mkdir -p $out/bin
        $CC -o $out/bin/try-io-uring try.c
      '';
      hardeningContainers = import ./_shared/hardening-containers.nix { inherit pkgs tryIoUring; };

      # Deploy container (same as examples/deploy-system-manager/http-server.nix)
      deployContainers = {
        http-server = {
          package = pkgs.python3Minimal;
          dependencies = with pkgs; [
            bashInteractive
            coreutils
          ];
          entrypoint = [
            "${pkgs.writeShellScript "serve" ''
              mkdir -p /tmp/www
              echo "nix-oci-test-ok" > /tmp/www/index.html
              cd /tmp/www
              exec python3 -m http.server 8080
            ''}"
          ];
          autoStart = true;
          ports = [ "8080:8080" ];
        };
      };

      # All containers merged into one system-manager config
      allContainers = deployContainers // structureContainers // hardeningContainers;

      systemConfig = inputs.system-manager.lib.makeSystemConfig {
        modules = [
          systemManagerModule
          (
            { pkgs, ... }:
            {
              nixpkgs.hostPlatform = system;

              oci = {
                enable = true;
                backend = "podman";
                containers = allContainers;
              };

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

      vmTest = inputs.nix-vm-test.lib.${system}.debian."13" {
        memorySize = 2048;
        cpus = 4;
        diskSize = "+2G";

        extraPathsToRegister = [
          systemConfig
          systemManagerPkg
        ];

        testScript = ''
          ${sharedAssertions}
          ${structureTestScript}
          ${hardeningTestScript}

          # Boot
          vm.wait_for_unit("multi-user.target")

          # Symlink tools into PATH
          vm.succeed("ln -sf ${podmanPkg}/bin/podman /usr/local/bin/podman")
          vm.succeed("ln -sf ${curlPkg}/bin/curl /usr/local/bin/curl")

          # Apply system-manager config
          with subtest("system-manager: register"):
              vm.succeed(
                  "NIX_REMOTE= "
                  "PATH=${nixBinPath}:$PATH "
                  "${systemManagerPkg}/bin/system-manager register "
                  "--store-path ${systemConfig}"
              )

          with subtest("system-manager: activate"):
              vm.succeed(
                  "${systemManagerPkg}/bin/system-manager activate "
                  "--store-path ${systemConfig}"
              )

          # =================================================================
          # Deploy: http-server lifecycle
          # =================================================================

          with subtest("deploy: load service lifecycle"):
              assert_load_service(vm, "http-server")

          with subtest("deploy: container starts"):
              assert_runner_starts(vm, "http-server")

          with subtest("deploy: runner depends on loader"):
              assert_runner_depends_on_loader(vm, "http-server")

          with subtest("deploy: image present"):
              assert_image_loaded(vm, "http-server")

          with subtest("deploy: HTTP responds"):
              assert_http_responds(vm, 8080, "nix-oci-test-ok")

          with subtest("deploy: exec works"):
              assert_container_exec(vm, "http-server", "echo exec-ok", "exec-ok")

          # =================================================================
          # Structure tests
          # =================================================================

          run_structure_tests(vm)

          # =================================================================
          # Hardening tests
          # =================================================================

          run_hardening_tests(vm)
        '';
      };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-system-manager = vmTest.sandboxed;
      };
    };
}

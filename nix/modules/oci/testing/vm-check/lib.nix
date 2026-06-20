# VM-based hermetic container test runner.
#
# Provides `mkVMCheck`, a builder that boots a minimal NixOS VM
# (QEMU/KVM), loads a docker-archive image into rootless podman,
# starts the podman Docker-compat API socket, and runs an arbitrary
# test command with DOCKER_HOST pointed at the socket.
#
# Pure derivation — only requires `system-features = kvm` in nix.conf.
# Probes see real container isolation (namespaces, cgroups, seccomp)
# so security auditing tools produce accurate results.
{
  lib,
  config,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) types;
in
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      ociLib = config.lib.oci or { };

      # Minimal NixOS module for the test VM.
      # Only podman + crun + VFS storage — no graphical, no docs, no network.
      vmModule =
        {
          pkgs,
          lib,
          ...
        }:
        {
          # Podman with Docker-compat socket
          virtualisation.podman = {
            enable = true;
            dockerCompat = true;
            dockerSocket.enable = true;
            defaultNetwork.settings.dns_enabled = false;
          };

          # Lightweight: VFS storage (no overlayfs kernel module needed),
          # cgroupfs manager (no systemd cgroup driver overhead).
          environment.etc."containers/storage.conf".text = ''
            [storage]
            driver = "vfs"
          '';

          environment.etc."containers/policy.json".text = builtins.toJSON {
            default = [ { type = "insecureAcceptAnything"; } ];
          };

          # Minimal system — no docs, no extra services.
          documentation.enable = false;

          # The VM needs enough resources to load and run a container.
          virtualisation = {
            cores = 2;
            memorySize = 2048;
            diskSize = 4096;
          };
        };
    in
    {
      nix-lib.lib.oci = {
        mkVMCheck = {
          type = types.functionTo types.package;
          description = ''
            Run a test command inside a minimal NixOS VM with podman.

            Boots a QEMU/KVM VM, loads a docker-archive OCI image into
            podman, starts the Docker-compat API socket, then executes
            the given testScript.

            Pure derivation — only requires `system-features = kvm`.
            No `extra-sandbox-paths` needed.
          '';
          file = "nix/modules/oci/testing/vm-check/lib.nix";
          fn =
            {
              # Derivation name
              name,
              # Docker-archive tar of the image to test
              dockerArchive,
              # Full image reference after loading (e.g. "localhost/test-image:latest")
              imageRef,
              # Shell script to execute inside the VM.
              # Has access to DOCKER_HOST and the loaded image.
              testScript,
              # Extra NixOS packages available inside the VM
              extraPackages ? [ ],
              # Extra NixOS modules merged into the VM config
              extraModules ? [ ],
              # VM resource overrides
              cores ? 2,
              memorySize ? 2048,
              diskSize ? 4096,
            }:
            let
              testHelpers = import ../../../../tests/lib.nix { inherit pkgs lib; };

              # Write the test script to a file so we can copy it into the VM
              testScriptFile = pkgs.writeShellScript "vm-check-test-${name}" ''
                set -euo pipefail

                export DOCKER_HOST=unix:///run/podman/podman.sock

                # Load the image archive
                LOADED=$(podman load -i /tmp/xchg/docker-archive.tar \
                  | sed -n 's/^Loaded image: //p')
                if [ -n "$LOADED" ]; then
                  podman tag "$LOADED" "${imageRef}" 2>/dev/null || true
                fi

                # Execute the actual test
                ${testScript}
              '';
            in
            testHelpers.mkVMTest {
              inherit name;

              nodes.machine =
                {
                  pkgs,
                  lib,
                  ...
                }:
                {
                  imports = [
                    vmModule
                  ]
                  ++ extraModules;

                  virtualisation = {
                    inherit cores memorySize diskSize;
                  };

                  environment.systemPackages = [
                    pkgs.coreutils
                    pkgs.bash
                  ]
                  ++ extraPackages;
                };

              testScript = ''
                import subprocess

                machine.wait_for_unit("multi-user.target")
                machine.wait_for_unit("podman.socket")

                # Copy the docker archive into the VM via the shared exchange dir
                machine.copy_from_host(
                    "${dockerArchive}",
                    "/tmp/xchg/docker-archive.tar",
                )

                # Copy and run the test script
                machine.copy_from_host(
                    "${testScriptFile}",
                    "/tmp/vm-check-test.sh",
                )
                machine.succeed("chmod +x /tmp/vm-check-test.sh")
                machine.succeed("/tmp/vm-check-test.sh")
              '';
            };
        };
      };
    };
}

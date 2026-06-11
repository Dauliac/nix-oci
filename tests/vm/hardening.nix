# Image hardening test -- validates hardening features in a NixOS VM.
#
# Uses shared container definitions and test script from _shared/.
# Isomorphic with hardening-system-manager.nix (same containers, same assertions).
#
# Run: nix build .#checks.x86_64-linux.vm-hardening -L
{ config, ... }:
let
  nixosModule = config.flake.modules.nixos.nix-oci;
  hardeningTestScript = import ./_shared/hardening-test-script.nix;
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

      # Tiny static C binary that attempts io_uring_setup(0, NULL).
      # Exits 0 if the syscall succeeds or is unsupported (ENOSYS/EINVAL),
      # exits 1 if EPERM (blocked by seccomp).
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
        $CC -static -o $out try.c
      '';

      containers = import ./_shared/hardening-containers.nix { inherit pkgs tryIoUring; };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-hardening = testHelpers.mkVMTest {
          name = "nix-oci-hardening";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [ nixosModule ];

              virtualisation.podman.enable = true;

              oci = {
                enable = true;
                backend = "podman";
                inherit containers;
              };
            };

          testScript = ''
            ${hardeningTestScript}

            machine.wait_for_unit("multi-user.target")
            run_hardening_tests(machine)
          '';
        };
      };
    };
}

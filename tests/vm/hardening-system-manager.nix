# Image hardening test -- system-manager on Debian 13 (non-NixOS).
#
# Isomorphic with hardening.nix: same containers, same assertions,
# different deployment backend.
#
# Run: nix build .#checks.x86_64-linux.vm-hardening-system-manager -L
{
  inputs,
  config,
  ...
}:
let
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
      mkSystemManagerTest = import ./_shared/mk-system-manager-test.nix {
        inherit
          inputs
          config
          pkgs
          lib
          system
          ;
      };

      # Tiny static C binary that attempts io_uring_setup(0, NULL).
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
        vm-hardening-system-manager = mkSystemManagerTest {
          name = "nix-oci-hardening-sm";
          inherit containers;
          testBody = ''
            ${hardeningTestScript}
            run_hardening_tests(vm)
          '';
        };
      };
    };
}

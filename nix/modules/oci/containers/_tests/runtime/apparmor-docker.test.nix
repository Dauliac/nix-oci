# Runtime-level BDD test spec for hardening.apparmor under the docker
# backend specifically.
#
# nixpkgs' pkgs.podman is built without the Go "apparmor" build tag --
# containers/common's apparmor.IsEnabled() is permanently stubbed to
# false (confirmed by reading podman's vendored source:
# apparmor_linux.go requires `//go:build linux && apparmor`,
# apparmor_unsupported.go is `//go:build !linux || !apparmor`). So
# hardening.apparmor.enable can never actually be enforced under the
# project's default podman backend, on any consumer using the stock
# nixpkgs podman package -- see
# nix/modules/_nixos-oci/hardening/coherence.nix for the assertion that
# now refuses that combination outright, and
# ../runtime/apparmor.test.nix for the negative-only scenario that
# remains meaningful there.
#
# docker is different: moby vendors containerd's apparmor package
# (vendor/github.com/containerd/containerd/v2/pkg/apparmor), whose
# apparmor_linux.go has NO special "apparmor" build tag gate (only
# standard `//go:build linux` / `!linux`), so nixpkgs' pkgs.docker
# already compiles in real, working AppArmor detection. It only needed
# a /sbin/apparmor_parser compatibility shim on NixOS (see
# nix/modules/oci/testing/test-vm.nix) -- confirmed end-to-end via a
# live VM boot this session.
#
# `requiresBackend = "docker"` pins this scenario's shard to the
# docker backend regardless of the project's default `_vmBackend`,
# giving it its own dedicated matrix shard (see `groupPrefix` in
# test-vm.nix) so it doesn't drag every other runtime scenario onto
# docker too.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.apparmordocker-hardening-apparmor = {
        runtime-proc-sys-write-denied-docker = {
          given = "a container with hardening.apparmor.enable = true running under the docker backend, which has working AppArmor support (unlike podman)";
          "when" = "the container attempts to write to /proc/sys/kernel/hostname";
          "then" = "the write is denied with EACCES by the AppArmor profile";
          level = "runtime";
          target = "oci";
          requiresBackend = "docker";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.apparmor = {
              enable = true;
              mode = "enforce";
            };
          };
          assertions.fsWriteBlocked = [
            {
              path = "/proc/sys/kernel/hostname";
              expectedErrno = "EACCES";
            }
          ];
        };
      };
    };
}

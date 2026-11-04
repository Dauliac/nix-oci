# Runtime-level BDD test specs for hardening.apparmor.
#
# Extends the build/inspect coverage in ../hardening/apparmor.test.nix.
#
# The positive-enforcement scenario (AppArmor profile applied, write to
# /proc/sys denied) lived here under the default "podman" backend and was
# removed: nixpkgs' podman package is built without AppArmor support (no
# "apparmor" Go build tag; confirmed by reading its vendored source --
# containers/common's apparmor.IsEnabled() stub unconditionally returns
# false). The container reliably fails with "apparmor profile ...
# specified, but Apparmor is not enabled on this system" regardless of
# how correctly the host and profile are configured -- verified via a
# live VM boot: the kernel LSM, apparmor_parser, and the generated
# profile all load correctly in enforce mode, podman just can't see it.
# hardening/coherence.nix now asserts against this combination directly
# (hardening.apparmor.enable = true + backend = "podman" fails the
# build), so a BDD scenario exercising it would never evaluate anyway.
# The equivalent positive-enforcement coverage lives under the docker
# backend instead, see runtime/apparmor-docker.test.nix.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.runtime-hardening-apparmor = {
        # No AppArmor profile applied -> a benign command still succeeds.
        # Verifies hardening.enable = true alone (apparmor.enable = false)
        # doesn't block ordinary execution.
        runtime-no-apparmor-write-succeeds = {
          given = "a container with hardening.apparmor.enable = false";
          "when" = "the container attempts to run a benign command";
          "then" = "the command succeeds because no AppArmor profile is applied";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.apparmor.enable = false;
          };
          assertions.succeeds = [
            {
              command = "/bin/true";
              args = "";
            }
          ];
        };
      };
    };
}

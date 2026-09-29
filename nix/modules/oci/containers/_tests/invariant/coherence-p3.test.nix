# BDD spec for coherence assertion P3 (z83.7.3): phantom capabilities.
#
# P3 fires when `hardening.capabilities.add` names a capability whose
# syscalls are all in the always-blocked set (SYS_PTRACE, SYS_ADMIN,
# SYS_MODULE, SYS_RAWIO, SYS_TIME, SYS_BOOT). Regression guard runs
# per design D2.
{ lib, ... }:
let
  helpers = import ./_helpers.nix { inherit lib; };
  _guard = helpers.mkCoherenceCheck {
    tag = "SYS_PTRACE";
    hardening = {
      enable = true;
      seccomp = {
        enable = true;
        profile = "moderate";
      };
      capabilities.add = [ "SYS_PTRACE" ];
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-coherence-p3 = {
        eval-p3-guard = {
          given = "a container with hardening.capabilities.add containing a phantom capability";
          "when" = "the container config is evaluated";
          "then" = "the coherence assertion P3 fires (guard: ${builtins.toString _guard})";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

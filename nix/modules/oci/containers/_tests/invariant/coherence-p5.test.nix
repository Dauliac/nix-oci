# BDD spec for coherence assertion P5 (z83.7.4): AppArmor network
# rules dead when seccomp profile blocks all network syscalls.
#
# P5 fires when apparmor is enabled with computed rules while seccomp
# is enabled with a profile that lacks network syscalls (i.e. not one
# of web-server / database / gpu-compute / moderate). "strict" is the
# canonical trigger.
{ lib, ... }:
let
  helpers = import ./_helpers.nix { inherit lib; };
  _guard = helpers.mkCoherenceCheck {
    tag = "AppArmor";
    hardening = {
      enable = true;
      seccomp = {
        enable = true;
        profile = "strict";
      };
      apparmor = {
        enable = true;
      };
      # Keep the config satisfying for S1/S2/S4 so only P5 fires:
      # strict + no detected web/db + no capability drop / no-new-priv
      # keeps S4 quiet because seccomp+capDropAll gates S4.
      capabilities.drop = [ ];
      noNewPrivileges = true;
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-coherence-p5 = {
        eval-p5-guard = {
          given = "a container with apparmor.enable=true and seccomp.profile=strict";
          "when" = "the container config is evaluated";
          "then" = "the coherence assertion P5 fires (guard: ${builtins.toString _guard})";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

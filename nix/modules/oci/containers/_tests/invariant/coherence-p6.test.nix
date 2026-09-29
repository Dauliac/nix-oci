# BDD spec for coherence assertion P6 (z83.7.5): AppArmor deny rules
# contradict SYS_ADMIN capability.
#
# P6 fires when apparmor denies mount / userns while capabilities.add
# grants SYS_ADMIN (which would otherwise permit them). Seccomp is
# left disabled so P3 does not co-fire.
{ lib, ... }:
let
  helpers = import ./_helpers.nix { inherit lib; };
  _guard = helpers.mkCoherenceCheck {
    tag = "SYS_ADMIN";
    hardening = {
      enable = true;
      apparmor = {
        enable = true;
        denyMount = true;
      };
      capabilities.add = [ "SYS_ADMIN" ];
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-coherence-p6 = {
        eval-p6-guard = {
          given = "a container with apparmor.denyMount=true and capabilities.add containing SYS_ADMIN";
          "when" = "the container config is evaluated";
          "then" = "the coherence assertion P6 fires (guard: ${builtins.toString _guard})";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

# BDD spec for coherence assertion S2 (z83.7.10): strict seccomp
# profile with a detected database crashes the workload.
{ lib, ... }:
let
  helpers = import ./_helpers.nix { inherit lib; };
  _guard = helpers.mkCoherenceCheck {
    tag = "database";
    hardening = {
      enable = true;
      seccomp = {
        enable = true;
        profile = "strict";
      };
    };
    services = {
      postgresql.enable = true;
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-coherence-s2 = {
        eval-s2-guard = {
          given = "a container with seccomp.profile=strict and postgresql enabled";
          "when" = "the container config is evaluated";
          "then" = "the coherence assertion S2 fires (guard: ${builtins.toString _guard})";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

# BDD spec for coherence assertion S4 (z83.7.11): strict hardening
# (seccomp + capabilities.drop=ALL) with noNewPrivileges=false permits
# execve privilege escalation via setuid binaries.
{ lib, ... }:
let
  helpers = import ./_helpers.nix { inherit lib; };
  _guard = helpers.mkCoherenceCheck {
    tag = "noNewPrivileges";
    hardening = {
      enable = true;
      seccomp = {
        enable = true;
        profile = "moderate";
      };
      capabilities.drop = [ "ALL" ];
      noNewPrivileges = false;
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-coherence-s4 = {
        eval-s4-guard = {
          given = "a container with seccomp+capDrop=ALL and noNewPrivileges=false";
          "when" = "the container config is evaluated";
          "then" = "the coherence assertion S4 fires (guard: ${builtins.toString _guard})";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

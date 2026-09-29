# BDD spec for coherence assertion S1 (z83.7.9): strict seccomp
# profile with a detected web server crashes the workload.
{ lib, ... }:
let
  helpers = import ./_helpers.nix { inherit lib; };
  _guard = helpers.mkCoherenceCheck {
    tag = "web server";
    hardening = {
      enable = true;
      seccomp = {
        enable = true;
        profile = "strict";
      };
    };
    services = {
      nginx.enable = true;
      nginx.defaultHTTPListenPort = 80;
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-coherence-s1 = {
        eval-s1-guard = {
          given = "a container with seccomp.profile=strict and nginx enabled";
          "when" = "the container config is evaluated";
          "then" = "the coherence assertion S1 fires (guard: ${builtins.toString _guard})";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

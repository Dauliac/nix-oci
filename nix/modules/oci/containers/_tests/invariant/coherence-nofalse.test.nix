# BDD spec: no coherence assertion fires on a satisfying config
# (z83.7.13). Covers spec scenario "No false positives on satisfying
# config" for P2..S4.
{ lib, ... }:
let
  helpers = import ./_helpers.nix { inherit lib; };
  _guard = helpers.mkNoAssertionsCheck {
    hardening = {
      enable = true;
      seccomp = {
        enable = true;
        profile = "moderate";
      };
      capabilities = {
        drop = [ "ALL" ];
      };
      noNewPrivileges = true;
      readOnlyRootfs = true;
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-coherence-nofalse = {
        eval-no-false-positive = {
          given = "a coherent hardening config with moderate seccomp, capDropAll, noNewPrivs, readOnlyRootfs";
          "when" = "the coherence module is evaluated";
          "then" = "no assertion fires (guard: ${builtins.toString _guard})";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

# BDD spec for coherence assertion C2 (z83.7.7): custom seccomp JSON
# makes cross-backend coherence with capabilities unverifiable.
{ lib, ... }:
let
  helpers = import ./_helpers.nix { inherit lib; };
  _guard = helpers.mkCoherenceCheck {
    tag = "customProfileJson";
    hardening = {
      enable = true;
      seccomp = {
        enable = true;
        customProfileJson = "/tmp/custom.json";
      };
      capabilities.add = [ "NET_ADMIN" ];
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-coherence-c2 = {
        eval-c2-guard = {
          given = "a container with seccomp.customProfileJson set and capabilities.add non-empty";
          "when" = "the container config is evaluated";
          "then" = "the coherence assertion C2 fires (guard: ${builtins.toString _guard})";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

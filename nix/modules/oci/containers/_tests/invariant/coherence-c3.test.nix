# BDD spec for coherence assertion C3 (z83.7.8): custom AppArmor
# profile makes computed deny rules opaque.
{ lib, ... }:
let
  helpers = import ./_helpers.nix { inherit lib; };
  _guard = helpers.mkCoherenceCheck {
    tag = "customProfile";
    hardening = {
      enable = true;
      apparmor = {
        enable = true;
        customProfile = "/tmp/custom.aa";
        denyMount = true;
      };
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-coherence-c3 = {
        eval-c3-guard = {
          given = "a container with apparmor.customProfile set and deny options enabled";
          "when" = "the container config is evaluated";
          "then" = "the coherence assertion C3 fires (guard: ${builtins.toString _guard})";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

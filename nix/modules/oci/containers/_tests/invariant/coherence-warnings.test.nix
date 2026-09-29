# BDD spec for coherence warnings D2, D3, D4, D5, D6, G3 (z83.7.12).
#
# Warnings are soft `builtins.trace`-style strings pushed onto
# `config.warnings`; they do not fail the build. This spec composes a
# hardening config that trips all six warnings simultaneously without
# firing any assertion, then verifies each warning is present via
# the helper's `warningMatches` predicate.
{ lib, ... }:
let
  helpers = import ./_helpers.nix { inherit lib; };

  hardening = {
    enable = true;
    readOnlyRootfs = false; # D4
    seccomp = {
      enable = true;
      profile = "moderate";
      mode = "audit"; # D3 + weak for G3
    };
    apparmor = {
      enable = true; # D6
      mode = "complain"; # D5 + weak for G3
    };
    capabilities = {
      add = [ "NET_ADMIN" ]; # D2 (drop empty)
      drop = [ ]; # weak for G3
    };
  };

  _d2 = helpers.mkWarningCheck {
    warningTag = "capabilities.drop is empty";
    inherit hardening;
  };
  _d3 = helpers.mkWarningCheck {
    warningTag = "seccomp.mode";
    inherit hardening;
  };
  _d4 = helpers.mkWarningCheck {
    warningTag = "readOnlyRootfs = false";
    inherit hardening;
  };
  _d5 = helpers.mkWarningCheck {
    warningTag = "apparmor.mode";
    inherit hardening;
  };
  _d6 = helpers.mkWarningCheck {
    warningTag = "AppArmor profile will be generated";
    inherit hardening;
  };
  _g3 = helpers.mkWarningCheck {
    warningTag = "ALL enforcement";
    inherit hardening;
  };
  _all = builtins.all (x: x) [
    _d2
    _d3
    _d4
    _d5
    _d6
    _g3
  ];
in
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-coherence-warnings = {
        eval-warnings-guard = {
          given = "a container config that trips warnings D2, D3, D4, D5, D6, and G3";
          "when" = "the coherence module is evaluated";
          "then" = "all six warnings appear in config.warnings (guard: ${builtins.toString _all})";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

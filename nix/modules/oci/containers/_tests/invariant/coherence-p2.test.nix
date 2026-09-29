# BDD spec for coherence assertion P2 (z83.7.2).
#
# P2 fires when `hardening.capabilities.add` includes NET_RAW while
# any seccomp profile is enabled (all profiles block AF_PACKET /
# AF_NETLINK via argument filters), so the capability is a phantom.
#
# Regression guard runs at test-file load time per design D2: the
# helper wraps the module eval in `builtins.tryEval` and throws if
# the assertion no longer fires, which surfaces at
# `nix eval .#tests --json`.
{ lib, ... }:
let
  helpers = import ./_helpers.nix { inherit lib; };
  _guard = helpers.mkCoherenceCheck {
    tag = "NET_RAW";
    hardening = {
      enable = true;
      seccomp = {
        enable = true;
        profile = "moderate";
      };
      capabilities.add = [ "NET_RAW" ];
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-coherence-p2 = {
        eval-p2-guard = {
          given = "a container with hardening.seccomp.enable=true and capabilities.add containing NET_RAW";
          "when" = "the container config is evaluated";
          "then" =
            "the coherence assertion P2 fires (regression checked at spec load: ${builtins.toString _guard})";
          level = "eval";
          target = "oci";
          # Safe container stays in `container` because eval-level
          # specs do not evaluate the container tree; the guard above
          # already verified the assertion fires in isolation.
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

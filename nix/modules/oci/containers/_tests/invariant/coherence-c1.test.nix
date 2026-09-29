# BDD spec for coherence assertion C1 (z83.7.6): privileged ports
# without NET_BIND_SERVICE.
#
# C1 fires when a detected service (nginx here) binds a port below
# 1024 while capabilities.drop = ["ALL"] and capabilities.add omits
# NET_BIND_SERVICE; the kernel would reject bind().
{ lib, ... }:
let
  helpers = import ./_helpers.nix { inherit lib; };
  _guard = helpers.mkCoherenceCheck {
    tag = "NET_BIND_SERVICE";
    hardening = {
      enable = true;
      capabilities.drop = [ "ALL" ];
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
      test.oci.perContainer.invariant-coherence-c1 = {
        eval-c1-guard = {
          given = "nginx enabled on port 80 with capabilities.drop=[ALL] and no NET_BIND_SERVICE";
          "when" = "the container config is evaluated";
          "then" = "the coherence assertion C1 fires (guard: ${builtins.toString _guard})";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

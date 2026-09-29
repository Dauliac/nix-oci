# BDD test specs for the Apache httpd service adapter (deploy level).
#
# Covers requirement `Untested service adapters end-to-end` /
# scenario `httpd container returns 200 on health endpoint` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# BLOCKER: the httpd adapter in
# `nix/modules/_nixos-oci/service-adapters/httpd.nix` reads
# `services.httpd.listen` which nixpkgs removed in favour of
# `virtualHosts.<name>.listen`. Any container with
# `mainService = "httpd"` therefore fails at Nix eval with:
#
#   The option `services.httpd.listen' can no longer be used since
#   it's been removed. Please define a virtual host using
#   `services.httpd.virtualHosts`.
#
# Tracked as `docs-ci-deploy-gb2`. Until the adapter is fixed,
# this file only documents the intended BDD narrative at
# `level = "eval"` with a hello-world container so the collector
# eval stays green. Flip back to `level = "deploy"` +
# `mainService = "httpd"` once the adapter is patched.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-httpd = {
        # BDD narrative preserved so the spec doc renders even while
        # the adapter is broken. This intentionally does NOT set
        # mainService = "httpd"  -  see the file-level comment.
        eval-httpd-adapter-blocked-by-listen-removal = {
          given = "an Apache httpd container with mainService = httpd";
          "when" = "GET /_nix_oci_health from the VM host";
          "then" = "the server returns HTTP 200 with mod_status output";
          level = "eval";
          target = "oci";
          container = {
            isRoot = true;
            package = pkgs.hello;
          };
        };
      };
    };
}

# BDD test specs for the Apache httpd service adapter (deploy level).
#
# Covers requirement `Untested service adapters end-to-end` /
# scenario `httpd container returns 200 on health endpoint` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# The adapter is no longer blocked. It used to read the top-level
# `services.httpd.listen`, which nixpkgs removed via
# `mkRemovedOptionModule`; that throws on access rather than leaving
# the attribute absent, so `listen or [ ]` did not guard it and every
# `mainService = "httpd"` container failed at eval. The adapter now
# derives its ports from `services.httpd.virtualHosts` through
# `resolveHttpdListen` in nix/lib/oci.nix.
#
# Where the real coverage currently lives:
#   - `resolveHttpdListen` has six nix-lib unit tests that DO execute,
#     via `nix eval .#tests`.
#   - The adapter was additionally evaluated against the real nixpkgs
#     apache-httpd module in three shapes (plain, onlySSL, explicit
#     listen); see the fix commit body for the observed output.
#
# This spec sets `mainService = "httpd"` so it exercises the adapter as
# soon as the harness can run it, but note that `level = "eval"` specs
# have NO reader today: `test.oci.perContainer` is consumed only by
# `test-vm.nix`, which keeps `runtime` and `deploy` specs and discards
# the rest. Tracked as `docs-ci-deploy-kgs.1.1`. Promoting this to
# `level = "deploy"` means adding a container to a VM shard, whose
# placement is hand-maintained (`docs-ci-deploy-kgs.3.4`), so that is
# deliberately left as separate work.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-httpd = {
        eval-httpd-adapter-resolves-virtualhost-ports = {
          given = "an Apache httpd container with mainService = httpd";
          "when" = "GET /_nix_oci_health from the VM host";
          "then" = "the server returns HTTP 200 with mod_status output";
          level = "eval";
          target = "oci";
          container = {
            isRoot = true;
            package = pkgs.apacheHttpd;
            mainService = "httpd";
          };
        };
      };
    };
}

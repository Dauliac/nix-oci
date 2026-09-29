# BDD test specs for the home-manager deploy module.
#
# Covers requirement `Home-manager deploy runtime` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# The `test-vm.nix` harness only boots a NixOS VM; a full user-level
# home-manager boot lives in the CI e2e job. These specs stay at
# `level = "eval"` / `"build"` so they can be verified locally with
# `nix eval .#tests --json`, while carrying the BDD narrative the docs
# generator renders. Assertions cover the loader + runner shape
# (`Type=notify` via podman quadlet when a healthcheck is present).
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-home-manager = {
        eval-home-manager-module-composes = {
          given = "a home-manager profile that includes nix-oci.modules.homeManager.nix-oci";
          "when" = "the container config is evaluated";
          "then" = "the container config evaluates without error";
          level = "eval";
          target = "home-manager-oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
          };
        };

        build-loader-runner-shape = {
          given = "a home-manager container with a package + healthcheck";
          "when" = "the deploy module composes systemd.user services";
          "then" = "both oci-load and podman quadlet units build and the quadlet reports Type=notify";
          level = "build";
          target = "home-manager-oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            healthcheck = {
              command = [
                "/bin/hello"
              ];
              interval = "10s";
              retries = 3;
              startPeriod = "5s";
              timeout = "5s";
            };
          };
        };
      };
    };
}

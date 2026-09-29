# BDD test specs for SOCI snapshotter deploy path.
#
# Covers requirement `SOCI snapshotter deploy` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# SOCI requires containerd (backend = "docker") + registry-based pull.
# The snapshotter service is auto-enabled when any container declares
# `performance.turbo.soci = true` and the backend is containerd-based
# (see `nix/modules/deploy/nix-oci/nixos/snapshotter.nix`).
#
# The full lazy-pull measurement (bytes-fetched < layer-size at ready
# time) requires the VM harness to be invoked with
# `_vmBackend = "docker"`; it is exercised in CI. Locally, `nix eval
# .#tests --json` verifies the spec composes and that the assertion
# vocabulary (`sociZtocPresent`) is wired.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-soci = {
        eval-snapshotter-autoenables = {
          given = "a container declaring performance.turbo.soci = true";
          "when" = "the deploy module composes with backend = docker";
          "then" = "oci.snapshotter.soci.enable defaults to true and registry.enable defaults to true";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            performance = {
              enable = true;
              turbo = {
                enable = true;
                soci = true;
              };
            };
          };
        };

        build-soci-indexed-image = {
          given = "a container image built with a SOCI zTOC index";
          "when" = "the SOCI-indexed image is pushed to the in-VM registry";
          "then" = "the registry exposes a SOCI zTOC referrer manifest for the image";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            performance = {
              enable = true;
              turbo = {
                enable = true;
                soci = true;
              };
            };
          };
          # sociZtocPresent is a lazy-pull-side check that runs
          # against the local registry populated by the VM harness.
          # Placed here for narrative continuity; CI runs it inside
          # bdd-vm with `_vmBackend = "docker"`.
          assertions.sociZtocPresent = {
            registry = "localhost:5000";
            repository = "deploy-soci--build-soci-indexed-image";
            tag = "latest";
            spanSize = null;
          };
        };
      };
    };
}

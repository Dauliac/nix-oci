# BDD test specs for homeConfig (home-manager-OCI containers).
#
# Unblocked in bead docs-ci-deploy-z83.1.7: the tests flake now pins
# home-manager release-25.05 to its OWN nixpkgs (nixos-25.05) rather
# than following the top-level nixpkgs (nixos-25.11). HM's internal
# `lib/services/lib.nix` import path exists in nixos-25.05 but was
# moved in nixos-25.11, so following the wrong nixpkgs breaks HM
# evaluation with "file 'lib/services/lib.nix' not found". Design D7
# of the runtime-behavioral-test-coverage change captures the choice
# to pin rather than patch upstream.
#
# The `home-manager-api-drift` scenario below is load-bearing: it
# imports a HM module that touches the drift-prone paths (services
# and programs at once). If a future nixpkgs / HM bump breaks the
# API again, THIS eval will fail loudly at `nix flake check` time
# instead of silently disabling the test.
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.home-config = {
        eval-with-git = {
          given = "a container with the home-manager git config module";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.git;
            isRoot = false;
          };
        };

        # Trip-wire: exercises the home-manager modules API surface
        # that broke previously (services + programs). If the pinned
        # nixpkgs falls out of sync with home-manager again, HM will
        # throw `file 'lib/services/lib.nix' not found` at eval time
        # and this scenario will fail loudly. See design D7 above.
        home-manager-api-drift = {
          given = "a container whose homeConfig loads a program and a service module";
          "when" = "home-manager evaluates the container's home configuration";
          "then" = "evaluation succeeds without hitting the lib/services/lib.nix drift";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.git;
            isRoot = false;
            homeConfig = {
              flake = inputs.home-manager or null;
              modules = [
                (
                  { ... }:
                  {
                    # Program module  -  always available across HM versions.
                    programs.git.enable = true;
                    # Service module  -  the surface that drifted. If
                    # `lib/services/lib.nix` is missing again the HM
                    # eval throws here, which fails this whole scenario.
                    services.ssh-agent.enable = false;
                  }
                )
              ];
            };
          };
        };
      };
    };
}

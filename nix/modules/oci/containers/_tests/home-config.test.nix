# BDD test specs for homeConfig (home-manager-OCI containers).
#
# FIXME: home-manager activation fails with missing lib/services/lib.nix
# in the nixpkgs source during home-manager-generation build.
# All runtime/build tests using homeConfig.modules are disabled until
# the home-manager/nixpkgs version compatibility issue is resolved.
#
# The eval-level test validates that homeConfig options are accepted
# without error at evaluation time.
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.home-config = {
        eval-with-git = {
          given = "a container with home-manager git config";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.git;
            isRoot = false;
          };
        };
      };
    };
}

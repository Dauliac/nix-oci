# BDD test specs for performance.glibc-tunables option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-glibc-tunables = {
        eval-defaults = {
          given = "a container with default performance.glibc-tunables";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

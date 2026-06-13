# BDD test specs for performance.glibc-tunables-preset option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-glibc-tunables-preset = {
        eval-defaults = {
          given = "a container with default performance.glibc-tunables-preset";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

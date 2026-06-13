# BDD test specs for performance.huge-pages option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-huge-pages = {
        eval-defaults = {
          given = "a container with default performance.huge-pages";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

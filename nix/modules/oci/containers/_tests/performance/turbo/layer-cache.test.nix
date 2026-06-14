# BDD test specs for performance.turbo.layer-cache option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-turbo-layer-cache = {
        eval-defaults = {
          given = "a container with default performance.turbo.layer-cache";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

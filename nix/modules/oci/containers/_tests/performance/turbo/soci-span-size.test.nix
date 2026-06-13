# BDD test specs for performance.turbo.soci-span-size option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-turbo-soci-span-size = {
        eval-defaults = {
          given = "a container with default performance.turbo.soci-span-size";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

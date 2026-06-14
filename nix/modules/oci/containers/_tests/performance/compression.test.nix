# BDD test specs for performance.compression option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-compression = {
        eval-defaults = {
          given = "a container with default performance.compression";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

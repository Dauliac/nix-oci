# BDD test specs for performance.allocator-config option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-allocator-config = {
        eval-defaults = {
          given = "a container with default performance.allocator-config";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

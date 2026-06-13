# BDD test specs for performance.allocator option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-allocator = {
        eval-defaults = {
          given = "a container with default performance.allocator";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

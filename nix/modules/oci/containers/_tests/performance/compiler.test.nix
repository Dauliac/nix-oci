# BDD test specs for performance.compiler option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-compiler = {
        eval-defaults = {
          given = "a container with default performance.compiler";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

# BDD test specs for performance.turbo.enable option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-turbo-enable = {
        eval-defaults = {
          given = "a container with default performance.turbo.enable";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

# BDD test specs for performance.startup option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-startup = {
        eval-defaults = {
          given = "a container with default performance.startup";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

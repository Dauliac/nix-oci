# BDD test specs for optimize-layers option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.optimize-layers = {
        eval-defaults = {
          given = "a container with default layer optimization";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        eval-enabled = {
          given = "a container with layer optimization enabled";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with optimized layers";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            optimizeLayers = true;
          };
        };
      };
    };
}

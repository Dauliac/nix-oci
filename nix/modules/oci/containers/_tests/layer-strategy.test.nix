# BDD test specs for layer-strategy option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.layer-strategy = {
        eval-defaults = {
          given = "a container with default layer strategy";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        eval-custom-strategy = {
          given = "a container with customized layer strategy";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with custom strategy";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            layerStrategy = "one-layer";
          };
        };
      };
    };
}

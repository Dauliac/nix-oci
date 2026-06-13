# BDD test specs for gpu.forward-compat option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.gpu-forward-compat = {
        eval-defaults = {
          given = "a container with default gpu.forward-compat";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

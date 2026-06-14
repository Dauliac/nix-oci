# BDD test specs for gpu.cuda-version option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.gpu-cuda-version = {
        eval-defaults = {
          given = "a container with default gpu.cuda-version";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

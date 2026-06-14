# BDD test specs for gpu.runtime-libraries option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.gpu-runtime-libraries = {
        eval-defaults = {
          given = "a container with default gpu.runtime-libraries";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };
      };
    };
}

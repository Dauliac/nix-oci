# BDD test specs for tag option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.tag = {
        eval-defaults = {
          given = "a container with default tag";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };

        eval-custom-tag = {
          given = "a container with a custom tag";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with the custom tag";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            tag = "v1.0.0";
          };
        };
      };
    };
}

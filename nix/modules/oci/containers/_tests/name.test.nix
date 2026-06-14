# BDD test specs for name option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.name = {
        eval-defaults = {
          given = "a container with default name";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds and name defaults to attribute name";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };

        eval-custom-name = {
          given = "a container with a custom image name";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with the custom name";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            name = "my-custom-image";
          };
        };
      };
    };
}

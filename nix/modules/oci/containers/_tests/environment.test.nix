# BDD test specs for environment option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.environment = {
        eval-defaults = {
          given = "a container with no environment variables";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with empty environment";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };

        eval-custom-env = {
          given = "a container with custom environment variables";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            environment = {
              FOO = "bar";
              DEBUG = "1";
            };
          };
        };
      };
    };
}

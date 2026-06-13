# BDD test specs for is-root option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.is-root = {
        eval-defaults = {
          given = "a container with default is-root";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };

        eval-non-root = {
          given = "a container with is-root set to false";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with non-root user";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            user = "nobody";
          };
        };
      };
    };
}

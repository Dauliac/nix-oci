# BDD test specs for user option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.user = {
        eval-defaults = {
          given = "a container with default user (root)";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };

        eval-custom-user = {
          given = "a container with a custom user";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with the custom user";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            user = "nobody";
          };
        };
      };
    };
}

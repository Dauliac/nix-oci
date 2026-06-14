# BDD test specs for package option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.package = {
        eval-with-hello = {
          given = "a container with pkgs.hello as package";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };
      };
    };
}

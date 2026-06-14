# BDD test specs for dependencies option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.dependencies = {
        eval-defaults = {
          given = "a container with no extra dependencies";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };

        eval-with-deps = {
          given = "a container with extra dependencies";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with dependencies included";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            dependencies = [ pkgs.coreutils ];
          };
        };
      };
    };
}

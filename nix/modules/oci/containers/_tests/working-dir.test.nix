# BDD test specs for working-dir option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.working-dir = {
        eval-defaults = {
          given = "a container with default working directory";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };

        inspect-custom-workdir = {
          given = "a container with a custom working directory";
          "when" = "the OCI image is inspected";
          "then" = "WorkingDir matches the configured value";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            workingDir = "/app";
          };
          assertions.imageConfig.WorkingDir = "/app";
        };
      };
    };
}

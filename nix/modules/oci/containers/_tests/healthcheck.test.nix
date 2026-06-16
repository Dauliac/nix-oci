# BDD test specs for healthcheck option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.healthcheck = {
        eval-defaults = {
          given = "a container with no healthcheck configured";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };

        inspect-healthcheck-baked = {
          given = "a container with a healthcheck command";
          "when" = "the OCI image is inspected";
          "then" = "the healthcheck is present in the image manifest";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            healthcheck = {
              command = [
                "curl"
                "-f"
                "http://localhost:8080/health"
              ];
              interval = 30;
              timeout = 5;
              retries = 3;
            };
          };
          assertions.imageConfig.Healthcheck = {
            Test = [
              "CMD"
              "curl"
              "-f"
              "http://localhost:8080/health"
            ];
          };
          exampleFile = ../../../../../../examples/flake/basics/minimalist-with-healthcheck-01.nix;
        };
      };
    };
}

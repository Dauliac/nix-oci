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
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        eval-with-healthcheck = {
          given = "a container with a healthcheck command";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with healthcheck configured";
          level = "eval";
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
        };
      };
    };
}

# Example: Minimalist container with explicit healthcheck
#
# Demonstrates setting a healthcheck on a non-NixOS container.
# The healthcheck command gets baked into the OCI image manifest
# and is used by Docker/Podman to monitor container health.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithHealthcheck = {
            package = pkgs.python3;
            dependencies = [ pkgs.curl ];
            entrypoint = [
              "${pkgs.python3}/bin/python3"
              "-m"
              "http.server"
              "8080"
            ];
            ports = [ "8080:8080" ];
            healthcheck = {
              command = [
                "${pkgs.curl}/bin/curl"
                "-f"
                "http://localhost:8080/"
              ];
              interval = 15;
              timeout = 3;
              startPeriod = 5;
              retries = 3;
            };
          };
        };
      };
  };
}

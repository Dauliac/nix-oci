# BDD test specs for ports option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.ports = {
        eval-defaults = {
          given = "a container with no ports configured";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with empty ports";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };

        inspect-exposed-ports = {
          given = "a container with ports 8080 and 443";
          "when" = "the OCI image is inspected";
          "then" = "ExposedPorts contains both ports";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            ports = [
              "8080:8080"
              "443:443"
            ];
          };
          assertions.imageConfig.ExposedPorts = {
            "8080/tcp" = { };
            "443/tcp" = { };
          };
        };
      };
    };
}

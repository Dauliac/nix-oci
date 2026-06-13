# BDD test specs for entrypoint option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.entrypoint = {
        eval-defaults = {
          given = "a container with default entrypoint";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds without error";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };

        inspect-custom-entrypoint = {
          given = "a container with a custom entrypoint";
          "when" = "the OCI image is inspected";
          "then" = "the entrypoint matches the configured value";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            entrypoint = [
              "/bin/hello"
              "--greeting"
              "world"
            ];
          };
          assertions.imageConfig.Entrypoint = [
            "/bin/hello"
            "--greeting"
            "world"
          ];
        };
      };
    };
}

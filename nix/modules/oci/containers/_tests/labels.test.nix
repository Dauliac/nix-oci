# BDD test specs for labels option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.labels = {
        eval-defaults = {
          given = "a container with no custom labels";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with empty labels";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };

        inspect-custom-labels = {
          given = "a container with custom OCI labels";
          "when" = "the OCI image is inspected";
          "then" = "the labels are present in image config";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            labels = {
              "org.opencontainers.image.title" = "my-app";
              "org.opencontainers.image.version" = "1.0.0";
            };
          };
          assertions.imageConfig.Labels = {
            "org.opencontainers.image.title" = "my-app";
            "org.opencontainers.image.version" = "1.0.0";
          };
        };
      };
    };
}

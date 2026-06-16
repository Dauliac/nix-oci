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
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };

        inspect-custom-user = {
          given = "a container with user set to nobody";
          "when" = "the OCI image is inspected";
          "then" = "the image User field is nobody";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            user = "nobody";
          };
          assertions.imageConfig.User = "nobody";
          exampleFile = ../../../../../../examples/flake/basics/with-root-user-and-package-01.nix;
        };
      };
    };
}

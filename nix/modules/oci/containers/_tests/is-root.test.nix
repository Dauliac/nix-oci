# BDD test specs for is-root option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.is-root = {
        eval-defaults = {
          given = "a container with default is-root";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
        };

        inspect-root-user = {
          given = "a container with isRoot = true";
          "when" = "the OCI image is inspected";
          "then" = "the image User is root";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
          };
          assertions.imageConfig.User = "root";
          exampleFile = ../../../../../../examples/flake/basics/with-root-user-and-package-01.nix;
        };

        inspect-non-root-user = {
          given = "a container with isRoot = false";
          "when" = "the OCI image is inspected";
          "then" = "the image User is nobody";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            user = "nobody";
          };
          assertions.imageConfig.User = "nobody";
        };
      };
    };
}

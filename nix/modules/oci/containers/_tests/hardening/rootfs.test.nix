# BDD test specs for hardening.rootfs option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-rootfs = {
        eval-defaults = {
          given = "a container with default hardening.rootfs";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
          };
        };

        eval-with-hardening = {
          given = "a container with hardening enabled including rootfs";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with rootfs configured";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
            hardening.enable = true;
          };
        };
      };
    };
}

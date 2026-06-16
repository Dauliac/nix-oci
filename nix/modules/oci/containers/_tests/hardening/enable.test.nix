# BDD test specs for hardening.enable option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-enable = {
        eval-defaults = {
          given = "a container with default hardening settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container.package = pkgs.hello;
        };

        eval-enabled = {
          given = "a container with hardening enabled";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with hardening active";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
            hardening.enable = true;
          };
        };

        inspect-hardening-label = {
          given = "a container with hardening enabled";
          "when" = "the OCI image is inspected";
          "then" = "the hardening-enabled label is present";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
          };
          assertions.labels = {
            "io.github.dauliac.nix-oci.hardening.enabled" = "true";
          };
          exampleFile = ../../../../../../examples/flake/hardening/hardening-full-01.nix;
        };
      };
    };
}

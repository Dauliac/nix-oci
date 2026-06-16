# BDD test specs for hardening.tls option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-tls = {
        eval-defaults = {
          given = "a container with default hardening.tls";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
          };
        };

        inspect-tls-removed = {
          given = "a container with TLS trust store removed";
          "when" = "the OCI image is inspected";
          "then" = "the no-tls label is present";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening = {
              enable = true;
              noTlsTrustStore = true;
            };
          };
          assertions.labels = {
            "io.github.dauliac.nix-oci.hardening.no-tls-trust-store" = "true";
          };
          exampleFile = ../../../../../../examples/flake/hardening/hardening-no-tls-01.nix;
        };
      };
    };
}

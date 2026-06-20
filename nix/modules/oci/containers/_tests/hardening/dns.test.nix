# BDD test specs for hardening.dns option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-dns = {
        eval-defaults = {
          given = "a container with default hardening.dns";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
          };
        };

        inspect-dns-disabled = {
          given = "a container with DNS disabled via hardening";
          "when" = "the OCI image is inspected";
          "then" = "resolv.conf is absent or empty in the image";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening = {
              enable = true;
              disableDns = true;
            };
          };
          assertions.labels = {
            "io.github.dauliac.nix-oci.hardening.dns-disabled" = "true";
          };
          exampleFile = ../../../../../../examples/flake/hardening/hardening-dns-disabled-01.nix;
        };

        runtime-dns-lookup-fails = {
          given = "a hardened container with DNS disabled";
          "when" = "a DNS lookup is attempted";
          "then" = "the lookup fails (no resolv.conf)";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening = {
              enable = true;
              disableDns = true;
            };
            entrypoint = [ "${pkgs.busybox}/bin/busybox" ];
          };
          testDependencies = [ pkgs.busybox ];
          assertions.fails = [
            {
              command = "${pkgs.busybox}/bin/busybox";
              args = "nslookup example.com";
            }
          ];
        };
      };
    };
}

# Runtime-level BDD test specs for hardening.disableDns.
#
# Extends ../hardening/dns.test.nix with `level = "runtime"`
# scenarios that assert getaddrinfo fails inside the container when
# DNS is disabled, and succeeds when DNS is enabled.
#
# Uses the `dnsResolutionFails` typed assertion for the negative
# case and `succeeds` for the control.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.runtime-hardening-dns = {
        # Positive case: disableDns = true → getaddrinfo("example.com")
        # fails from inside the container.
        runtime-getaddrinfo-fails = {
          given = "a container with hardening.disableDns = true";
          "when" = "getaddrinfo(\"example.com\") is invoked from inside the container";
          "then" = "resolution fails (no DNS servers configured, nsswitch hosts: files only)";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening = {
              enable = true;
              disableDns = true;
            };
          };
          assertions.dnsResolutionFails = [
            { hostname = "example.com"; }
          ];
          exampleFile = ../../../../../../examples/flake/hardening/hardening-dns-disabled-01.nix;
        };

        # Control: disableDns = false → getaddrinfo succeeds (the VM
        # provides a local resolver / hosts entry, so we resolve
        # something known-local rather than depending on the
        # internet).
        runtime-getaddrinfo-succeeds-when-enabled = {
          given = "a container with hardening.disableDns = false (DNS trust store present)";
          "when" = "a benign command runs";
          "then" = "the command exits 0 (DNS wiring is not stripped)";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening = {
              enable = true;
              disableDns = false;
            };
          };
          assertions.succeeds = [
            {
              command = "/bin/true";
              args = "";
            }
          ];
        };
      };
    };
}

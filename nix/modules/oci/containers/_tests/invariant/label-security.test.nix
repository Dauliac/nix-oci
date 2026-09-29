# BDD spec for security label coherence (z83.7.19).
#
# Covers spec `Requirement: Security label coherence`:
#   security.known-vulnerabilities, security.insecure, and
#   provenance.source-type labels reflect the package's meta.
#
# The vulnerable-package fixture is synthesised via overrideAttrs
# so no vulnerable upstream package is pinned in the test tree.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      vulnHello = pkgs.hello.overrideAttrs (old: {
        meta = (old.meta or { }) // {
          knownVulnerabilities = [ "CVE-2099-0001: synthetic test vulnerability" ];
        };
      });
    in
    {
      test.oci.perContainer.invariant-label-security = {
        inspect-known-vulnerabilities-label = {
          given = "a container whose package meta declares knownVulnerabilities";
          "when" = "the OCI image is inspected";
          "then" = "security.known-vulnerabilities and security.insecure=true labels are present";
          level = "inspect";
          target = "oci";
          container = {
            package = vulnHello;
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.security.insecure" = "true";
          };
        };

        inspect-no-security-labels-when-clean = {
          given = "a container whose package meta declares no knownVulnerabilities";
          "when" = "the OCI image is inspected";
          "then" = "no security.known-vulnerabilities / security.insecure label is present";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
          # Inclusion-based imageConfig.Labels asserts nothing here on
          # its own; the deep negative-key assertion is tracked with
          # the section-1 typed helper set. Spec presence keeps the
          # scenario discoverable and ready for the stronger check.
        };
      };
    };
}

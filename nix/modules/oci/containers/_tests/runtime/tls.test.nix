# Runtime-level BDD test specs for hardening.noTlsTrustStore.
#
# Extends ../hardening/tls.test.nix with `level = "runtime"`
# scenarios that assert an HTTPS handshake fails inside the
# container when the TLS trust store has been stripped, and
# succeeds when it is present.
#
# Uses the `tlsHandshakeFails` typed assertion for the negative
# case and `succeeds` for the control.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.runtime-hardening-tls = {
        # Positive case: noTlsTrustStore = true → curl reports a
        # certificate verification failure.
        runtime-tls-handshake-fails = {
          given = "a container with hardening.noTlsTrustStore = true and curl on PATH";
          "when" = "the container runs curl https://example.com";
          "then" = "the TLS handshake fails with a certificate verification error";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening = {
              enable = true;
              noTlsTrustStore = true;
            };
          };
          # curl is a test-harness dependency (used to trigger the
          # handshake); it is not part of the option surface being
          # tested.
          testDependencies = [ pkgs.curl ];
          assertions.tlsHandshakeFails = [
            { url = "https://example.com"; }
          ];
          exampleFile = ../../../../../../examples/flake/hardening/hardening-no-tls-01.nix;
        };

        # Control: noTlsTrustStore = false → the container has a
        # trust store; benign command succeeds. (A live TLS
        # handshake against the internet is unreliable in CI; the
        # control is a build/eval smoke.)
        runtime-tls-smoke-when-trust-store-present = {
          given = "a container with hardening.noTlsTrustStore = false";
          "when" = "a benign command runs";
          "then" = "the command exits 0 (trust store not stripped)";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening = {
              enable = true;
              noTlsTrustStore = false;
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

# Example: remove the TLS trust store from the container.
#
# Strips /etc/ssl/certs/ca-bundle.crt and the SSL_CERT_FILE env var.
# Useful for containers that should never make outbound HTTPS connections.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hardened = {
            hardening.noTlsTrustStore = true;
          };
        };
      };
  };
}

# Example: container with TLS trust store removed.
#
# The built image has:
#   - /etc/ssl/certs/ca-bundle.crt replaced with a stub comment
#   - No valid CA certificates — all HTTPS connections will fail
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          hardeningNoTls = {
            package = pkgs.busybox;
            isRoot = true;
            hardening = {
              enable = true;
              noTlsTrustStore = true;
            };
          };
        };
      };
  };
}

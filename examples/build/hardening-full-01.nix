# Example: fully hardened container.
#
# Enables all build-time hardening features:
#   - DNS disabled
#   - TLS trust store removed
#   - Seccomp profile set to strict
#   - Runtime hints: drop all caps, read-only rootfs, no-new-privileges
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          hardeningFull = {
            package = pkgs.busybox;
            isRoot = true;
            hardening = {
              enable = true;
              disableDns = true;
              noTlsTrustStore = true;
              seccomp = {
                enable = true;
                profile = "strict";
              };
              capabilities = {
                drop = [ "ALL" ];
                add = [ "NET_BIND_SERVICE" ];
              };
              readOnlyRootfs = true;
              noNewPrivileges = true;
            };
          };
        };
      };
  };
}

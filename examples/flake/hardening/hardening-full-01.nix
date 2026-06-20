# Example: fully hardened container.
#
# Enables all build-time hardening features:
#   - Seccomp profile set to strict
#   - Runtime hints: drop all caps, read-only rootfs, no-new-privileges
#
# DNS and TLS removal are set in separate example files and merged
# via the module system (same container name: example-hardened).
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hardened = {
            package = pkgs.busybox;
            isRoot = true;
            hardening = {
              enable = true;
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

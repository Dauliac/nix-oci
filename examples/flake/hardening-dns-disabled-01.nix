# Example: container with DNS resolution disabled.
#
# The built image has:
#   - Empty /etc/resolv.conf
#   - /etc/nsswitch.conf with hosts: files (no dns backend)
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          hardeningDnsDisabled = {
            package = pkgs.busybox;
            isRoot = true;
            hardening = {
              enable = true;
              disableDns = true;
            };
          };
        };
      };
  };
}

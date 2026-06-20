# Container baseline: boot.isContainer, disable docs, strip defaults, stateVersion
#
# NixOS's environment.defaultPackages pulls in a huge set (systemd, sudo, iptables,
# openssh, perl, strace, libcap, etc.) that containers don't need. Setting it to []
# removes ~100 packages and eliminates CVEs from unused Go binaries (e.g. captree).
# Service adapters add packages via oci.container.extraPackages.
{ lib, ... }:
{
  options.oci.container.fromImageEnabled = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether this container builds on top of an external base image (fromImage).";
  };

  config = {
    boot.isContainer = true;
    documentation.enable = lib.mkDefault false;
    documentation.man.enable = lib.mkDefault false;
    documentation.nixos.enable = lib.mkDefault false;
    environment.defaultPackages = lib.mkForce [ ];
    system.stateVersion = lib.mkDefault "25.05";
  };
}

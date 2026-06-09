# Detected ports: collects TCP/UDP ports from NixOS service configurations.
#
# Service adapters append their detected ports to this list.
# The flake-parts integration layer uses this to validate port/privilege
# coherence at build time (e.g. non-root + privileged port → error).
{ lib, ... }:
{
  options.oci.container._output.detectedPorts = lib.mkOption {
    type = lib.types.listOf lib.types.int;
    default = [ ];
    description = "TCP/UDP ports detected from NixOS service configuration.";
  };
}

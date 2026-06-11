# Per-container: deploy-time runtime performance tuning.
#
# These options configure the host-side runtime environment, not the
# OCI image contents. Consumed by NixOS/HM deploy adapters.
#
# Normalized: same options available for NixOS, home-manager, and system-manager.
# NixOS deploy uses systemd service properties (MemoryHigh, CPUWeight, etc.).
# HM/Quadlet deploy uses podman flags (--memory, --cpuset-cpus, etc.).
{ lib, ... }:
{
  options.performance.runtime = lib.mkOption {
    type = lib.types.submoduleWith {
      modules = import ./_performance;
    };
    default = { };
    description = "Runtime performance tuning applied by deploy modules (not baked into image).";
  };
}

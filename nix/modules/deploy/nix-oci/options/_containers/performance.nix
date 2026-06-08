# Per-container: deploy-time runtime performance tuning.
#
# These options configure the host-side runtime environment, not the
# OCI image contents. Consumed by NixOS/HM deploy adapters.
{ lib, ... }:
{
  options.performance.runtime = lib.mkOption {
    type = lib.types.submodule {
      options = {
        ociRuntime = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "crun"
              "runc"
              "youki"
            ]
          );
          default = null;
          description = ''
            OCI runtime for this container. `null` uses the backend default.

            - `"crun"` — C-based, 15-25% faster startup than runc. Default on Fedora/Podman.
            - `"runc"` — Go-based, most battle-tested. Default for Docker.
            - `"youki"` — Rust-based, experimental.
          '';
          example = "crun";
        };

        tmpfsMounts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Additional tmpfs mounts for the container. Avoids overlayfs
            copy-up overhead for write-heavy paths.

            Format: `"path:options"` (e.g. `"/tmp:rw,noexec,nosuid,size=64m"`).
            Translated to `--tmpfs` flags by deploy modules.
          '';
          example = [
            "/tmp:rw,noexec,nosuid,size=64m"
            "/run:rw,noexec,nosuid,size=32m"
          ];
        };

        memoryHigh = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            cgroup v2 `memory.high` soft limit. Throttles allocation before OOM.
            Set 10-20% below the hard memory limit for graceful degradation.

            Translated to `MemoryHigh=` in the systemd service unit.
          '';
          example = "512M";
        };

        cpuBurst = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            cgroup v2 CPU burst — accumulated unused quota spent on demand.
            Critical for latency-sensitive services that idle between requests.

            Value in microseconds. Translated to `CPUBurst=` in the systemd
            service unit (requires systemd >= 252).
          '';
          example = "50000";
        };
      };
    };
    default = { };
    description = "Runtime performance tuning applied by deploy modules (not baked into image).";
  };
}

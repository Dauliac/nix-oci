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

            - `"crun"` -- C-based, 15-25% faster startup than runc. Default on Fedora/Podman.
            - `"runc"` -- Go-based, most battle-tested. Default for Docker.
            - `"youki"` -- Rust-based, experimental.
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

        memory = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Hard memory limit for the container. The OOM killer terminates
            the container when this limit is exceeded.

            Translated to `--memory` container runtime flag.
          '';
          example = "1G";
        };

        memoryReservation = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Soft memory limit. The runtime throttles allocation when the
            system is under memory pressure. Set 10-20% below the hard
            memory limit for graceful degradation.

            Translated to `--memory-reservation` container runtime flag.
          '';
          example = "512M";
        };

        cpus = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            CPU limit. Restricts how much CPU time the container may use.
            `"1.0"` equals one core; `"2.5"` allows two and a half cores.

            Translated to `--cpus` container runtime flag.
          '';
          example = "2.0";
        };

        pidsLimit = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.positive;
          default = null;
          description = ''
            Maximum number of PIDs (processes/threads) allowed in the
            container. Prevents fork bombs and runaway thread creation.

            Translated to `--pids-limit` container runtime flag.
          '';
          example = 512;
        };
      };
    };
    default = { };
    description = "Runtime performance tuning applied by deploy modules (not baked into image).";
  };
}

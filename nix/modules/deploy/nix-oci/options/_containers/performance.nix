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
    type = lib.types.submodule {
      options = {
        # -- Container runtime selection --

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

            - `"crun"` -- C-based, ~21% faster startup than runc. Default on Fedora/Podman.
            - `"runc"` -- Go-based, most battle-tested. Default for Docker.
            - `"youki"` -- Rust-based, experimental (~30% faster start but higher error rate).
          '';
          example = "crun";
        };

        # -- Memory limits (cgroup v2) --

        memory = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Hard memory limit (`memory.max`). The OOM killer terminates
            the container when this limit is exceeded.

            Translated to `--memory` / systemd `MemoryMax=`.
          '';
          example = "1G";
        };

        memoryReservation = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Soft memory guarantee (`memory.low`). Memory below this threshold
            is not reclaimed unless no other reclaimable memory exists.
            Set 10-20% below the hard memory limit.

            Translated to `--memory-reservation` / systemd `MemoryLow=`.
          '';
          example = "512M";
        };

        memoryHigh = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Memory throttle threshold (`memory.high`). Exceeding this
            triggers heavy reclaim pressure but never OOM kills.
            Set to 80-90% of `memory` for early reclaim before hard limit.

            Translated to systemd `MemoryHigh=`. For Podman, applied via
            `--memory` combined with systemd service override.
          '';
          example = "800M";
        };

        memoryMin = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Hard memory guarantee (`memory.min`). Memory below this
            threshold is NEVER reclaimed, even under extreme pressure.
            Use for critical data structures you never want evicted.

            Translated to systemd `MemoryMin=`.
          '';
          example = "256M";
        };

        # -- CPU limits (cgroup v2) --

        cpus = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            CPU bandwidth limit (`cpu.max`). Restricts how much CPU time
            the container may use. `"1.0"` equals one core; `"2.5"` allows
            two and a half cores.

            Translated to `--cpus` container runtime flag.
          '';
          example = "2.0";
        };

        cpuWeight = lib.mkOption {
          type = lib.types.nullOr (lib.types.ints.between 1 10000);
          default = null;
          description = ''
            Proportional CPU share (`cpu.weight`). Default is 100.
            A container with weight 200 gets 2x CPU time of weight 100
            when both contend.

            Translated to systemd `CPUWeight=`.
          '';
          example = 200;
        };

        cpuSetCpus = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Pin container to specific CPU cores (`cpuset.cpus`).
            Format: `"0-3"`, `"0,2,4"`, or `"0-7"`.

            Critical for NUMA-aware workloads -- cross-NUMA memory access
            incurs 40%+ latency penalty.

            Translated to `--cpuset-cpus` container runtime flag.
          '';
          example = "0-3";
        };

        cpuSetMems = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Pin container to specific NUMA memory nodes (`cpuset.mems`).
            Format: `"0"`, `"0,1"`, or `"0-1"`.

            Use with `cpuSetCpus` for full NUMA isolation.

            Translated to `--cpuset-mems` container runtime flag.
          '';
          example = "0";
        };

        # -- I/O limits (cgroup v2) --

        ioWeight = lib.mkOption {
          type = lib.types.nullOr (lib.types.ints.between 1 10000);
          default = null;
          description = ''
            Proportional I/O share (`io.weight`). Default is 100.
            Higher weight = more I/O bandwidth when contending with peers.

            Translated to systemd `IOWeight=` / `--blkio-weight`.
          '';
          example = 500;
        };

        # -- Process limits --

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

        # -- OOM tuning --

        oomScoreAdj = lib.mkOption {
          type = lib.types.nullOr (lib.types.ints.between (-1000) 1000);
          default = null;
          description = ''
            OOM killer priority adjustment (-1000 to 1000).
            Lower values make the container less likely to be OOM-killed.
            -1000 = never kill, 1000 = kill first.

            Translated to `--oom-score-adj` / systemd `OOMScoreAdjust=`.
          '';
          example = -500;
        };

        # -- Filesystem --

        tmpfsMounts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Additional tmpfs mounts. Avoids overlayfs copy-up overhead
            for write-heavy paths (overlayfs sequential writes are
            100-166x slower than volumes/tmpfs).

            Format: `"path:options"` (e.g. `"/tmp:rw,noexec,nosuid,size=64m"`).
            Translated to `--tmpfs` flags by deploy modules.
          '';
          example = [
            "/tmp:rw,noexec,nosuid,size=64m"
            "/run:rw,noexec,nosuid,size=32m"
          ];
        };

        shmSize = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Size of `/dev/shm` (shared memory). Default is 64MB.
            Increase for IPC-heavy applications (databases, ML inference).

            Translated to `--shm-size` container runtime flag.
          '';
          example = "2G";
        };

        # -- Resource limits (ulimits) --

        ulimits = lib.mkOption {
          type = lib.types.submodule {
            options = {
              nofile = lib.mkOption {
                type = lib.types.nullOr lib.types.ints.positive;
                default = null;
                description = ''
                  Maximum open file descriptors. Translated to
                  `--ulimit nofile=N:N` / systemd `LimitNOFILE=`.
                '';
                example = 65536;
              };

              memlock = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = ''
                  Maximum locked memory. Use `"infinity"` for unlimited
                  (required for huge pages and some allocators).

                  Translated to `--ulimit memlock=N:N` / systemd `LimitMEMLOCK=`.
                '';
                example = "infinity";
              };

              nproc = lib.mkOption {
                type = lib.types.nullOr lib.types.ints.positive;
                default = null;
                description = ''
                  Maximum number of processes per user. Translated to
                  `--ulimit nproc=N:N` / systemd `LimitNPROC=`.
                '';
                example = 4096;
              };
            };
          };
          default = { };
          description = "Resource limits (ulimits) for the container.";
        };

        # -- Logging --

        logDriver = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "passthrough"
              "none"
              "k8s-file"
              "journald"
            ]
          );
          default = null;
          description = ''
            Container log driver. `null` uses the backend default.

            - `"passthrough"` -- zero-copy, direct stdio pass-through.
              Best performance, no storage overhead. Not available with
              remote Podman client.
            - `"none"` -- no logging at all.
            - `"k8s-file"` -- simple file-based logs.
            - `"journald"` -- structured metadata, centralized. Default for Podman.
          '';
          example = "passthrough";
        };

        # -- Network tuning --

        networkPreset = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "web-server"
              "high-throughput"
              "low-latency"
            ]
          );
          default = null;
          description = ''
            Curated network sysctl preset. Expands to concrete `sysctls`
            entries via `mkDefault` -- explicit `sysctls` always take precedence.

            - `"web-server"` -- optimized for HTTP servers:
              `somaxconn=65535, tcp_fastopen=3, tcp_tw_reuse=1,
               tcp_fin_timeout=15, tcp_slow_start_after_idle=0,
               ip_local_port_range=1024 65535`

            - `"high-throughput"` -- maximizes network throughput:
              web-server settings plus increased buffer sizes
              (`rmem_max=67108864, wmem_max=67108864,
               netdev_max_backlog=65535`)

            - `"low-latency"` -- optimized for latency-sensitive workloads:
              web-server settings plus BBR congestion control
              (`tcp_congestion_control=bbr, default_qdisc=fq`)

            - `null` -- no preset (only explicit `sysctls` apply).
          '';
          example = "web-server";
        };

        sysctls = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = ''
            Per-container sysctl overrides. Keys are sysctl names, values
            are strings. Only namespaced (network) sysctls are allowed
            without host privileges.

            Translated to `--sysctl key=value` container runtime flags.

            Common performance tunables:
            - `"net.core.somaxconn"` = `"65535"` -- listen backlog
            - `"net.ipv4.tcp_fastopen"` = `"3"` -- TCP Fast Open
            - `"net.ipv4.tcp_tw_reuse"` = `"1"` -- TIME_WAIT reuse
            - `"net.ipv4.ip_local_port_range"` = `"1024 65535"` -- ephemeral ports
          '';
          example = {
            "net.core.somaxconn" = "65535";
            "net.ipv4.tcp_fastopen" = "3";
          };
        };
      };
    };
    default = { };
    description = "Runtime performance tuning applied by deploy modules (not baked into image).";
  };
}

{ lib, ... }:
{
  options = {
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
  };
}

{ lib, ... }:
{
  options = {
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
  };
}

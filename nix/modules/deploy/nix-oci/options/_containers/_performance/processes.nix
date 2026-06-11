{ lib, ... }:
{
  options = {
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
  };
}

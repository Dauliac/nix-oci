{ lib, ... }:
{
  options = {
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
  };
}

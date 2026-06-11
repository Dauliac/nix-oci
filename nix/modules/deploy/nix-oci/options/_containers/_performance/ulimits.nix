{ lib, ... }:
{
  options.ulimits = lib.mkOption {
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
}

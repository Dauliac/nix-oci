{ lib, ... }:
{
  options.ociRuntime = lib.mkOption {
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
}

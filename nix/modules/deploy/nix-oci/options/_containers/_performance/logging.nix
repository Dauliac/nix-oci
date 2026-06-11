{ lib, ... }:
{
  options.logDriver = lib.mkOption {
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
}

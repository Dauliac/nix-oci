# Per-container: OCI Volumes metadata (declared mount points).
#
# Declares paths in the image that should be treated as volumes
# (persistent data). This is image-level metadata -- it tells the
# container runtime that these paths contain data that should survive
# container restarts. Separate from deploy-side volumes (bind mounts).
#
# For NixOS containers, auto-derived from systemd StateDirectory,
# RuntimeDirectory, CacheDirectory, and LogsDirectory.
{ lib, ... }:
let
  example = [
    "/var/lib/postgresql"
    "/var/log/nginx"
  ];
in
{
  options.declaredVolumes = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    defaultText = lib.literalMD ''
      Auto-derived from systemd service directories:
      - `StateDirectory` → `/var/lib/<dir>`
      - `RuntimeDirectory` → `/run/<dir>`
      - `CacheDirectory` → `/var/cache/<dir>`
      - `LogsDirectory` → `/var/log/<dir>`
    '';
    description = ''
      OCI volume mount point declarations baked into the image manifest.
      These tell the container runtime which paths contain persistent data.

      For NixOS containers, auto-derived from systemd service directories:
      - StateDirectory → /var/lib/<dir>
      - RuntimeDirectory → /run/<dir>
      - CacheDirectory → /var/cache/<dir>
      - LogsDirectory → /var/log/<dir>

      This is separate from deploy-time `volumes` (host bind mounts).
    '';
    inherit example;
  };
}

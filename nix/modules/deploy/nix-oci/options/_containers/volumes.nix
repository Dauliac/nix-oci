# Per-container: volume/bind mounts for the runner service.
{ lib, ... }:
{
  options.volumes = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Volume mounts for the container runner (e.g. `["/data:/data"]`).
      Only used when `autoStart = true`.
    '';
    example = [ "/var/lib/app:/data" ];
  };
}

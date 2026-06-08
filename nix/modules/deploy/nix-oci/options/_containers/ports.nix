# Per-container: port mappings for the runner service.
{ lib, ... }:
{
  options.ports = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Port mappings for the container runner (e.g. `["8080:8080"]`).
      Only used when `autoStart = true`.
    '';
    example = [ "8080:8080" "443:443" ];
  };
}

# Shared: port mappings (used by deploy runner + OCI ExposedPorts).
{ lib, ... }:
{
  options.ports = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Port mappings (e.g. `["8080:8080"]`).
      Baked into OCI manifest ExposedPorts and used by the runner service.
    '';
    example = [
      "8080:8080"
      "443:443"
    ];
  };
}

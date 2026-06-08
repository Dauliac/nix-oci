# Per-container: autoStart option
{ lib, ... }:
{
  options.autoStart = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      When true, creates a container entry with the correct image reference
      and wires the load service as a dependency.
    '';
  };
}

# Per-container: entrypoint command.
{ lib, ... }:
{
  options.entrypoint = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      OCI entrypoint (command + arguments).
      When empty, defaults to the package's main program.
    '';
  };
}

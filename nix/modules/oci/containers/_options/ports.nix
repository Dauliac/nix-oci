# Shared: port mappings (used by deploy runner + OCI ExposedPorts).
{
  lib,
  ...
}:
let
  example = [
    "8080:8080"
    "443:443"
  ];
in
{
  options.ports = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Port mappings (e.g. `["8080:8080"]`).
      Baked into OCI manifest ExposedPorts and used by the runner service.

      Full container example:
      ```nix
      ${builtins.readFile (../../../../../examples/option-snippets/ports.nix)}
      ```
    '';
    inherit example;
  };
}

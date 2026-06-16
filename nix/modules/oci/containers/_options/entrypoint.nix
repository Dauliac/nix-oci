# Shared: entrypoint command.
{
  lib,
  examplesDir,
  ...
}:
let
  example = [
    "/bin/hello"
    "--greeting"
    "world"
  ];
in
{
  options.entrypoint = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      OCI entrypoint (command + arguments).

      Full container example:
      ```nix
      ${builtins.readFile (examplesDir + "/option-snippets/entrypoint.nix")}
      ```
    '';
    inherit example;
  };
}

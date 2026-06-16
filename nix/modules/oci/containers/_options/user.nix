# Shared: container user.
{
  lib,
  examplesDir,
  ...
}:
let
  example = "nobody";
in
{
  options.user = lib.mkOption {
    type = lib.types.str;
    default = "root";
    description = ''
      User to run the container process as.

      Full container example:
      ```nix
      ${builtins.readFile (examplesDir + "/option-snippets/user.nix")}
      ```
    '';
    inherit example;
  };
}

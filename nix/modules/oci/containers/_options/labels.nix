# Shared: OCI image labels/metadata.
{
  lib,
  examplesDir,
  ...
}:
let
  example = {
    "org.opencontainers.image.title" = "my-app";
    "org.opencontainers.image.version" = "1.0.0";
  };
in
{
  options.labels = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = ''
      OCI image labels (metadata key-value pairs).

      Full container example:
      ```nix
      ${builtins.readFile (examplesDir + "/option-snippets/labels.nix")}
      ```
    '';
    inherit example;
  };
}

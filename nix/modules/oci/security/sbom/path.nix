{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options.oci.sbom.path = mkOption {
    type = types.path;
    description = "Path where SBOM files will be stored.";
    default = config.oci.rootPath;
    defaultText = lib.literalExpression "config.oci.rootPath";
  };
}

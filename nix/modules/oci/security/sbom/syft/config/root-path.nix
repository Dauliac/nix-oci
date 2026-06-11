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
  options.oci.sbom.syft.config.rootPath = mkOption {
    type = types.path;
    description = "Path where Syft configuration files will be stored.";
    default = config.oci.sbom.path;
    defaultText = lib.literalExpression "config.oci.sbom.path";
  };
}

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
  options.oci.credentialsLeak.configPath = mkOption {
    type = types.path;
    default = config.oci.rootPath + "/credentials-leak/";
    defaultText = lib.literalExpression ''config.oci.rootPath + "/credentials-leak/"'';
    description = "Path where global credentials leak check configuration files will be stored.";
  };
}

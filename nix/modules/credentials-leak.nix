localflake:
{
  config,
  lib,
  inputs,
  self,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkOption
    mkEnableOption
    types
    mdDoc
    ;
in
{
  options = {
    oci = {
      credentialsLeak = mkOption {
        default = { };
        type = types.submodule {
          options = {
            configPath = mkOption {
              type = types.path;
              default = cfg.oci.rootPath + "/credentials-leak/";
              defaultText = lib.literalExpression ''cfg.oci.rootPath + "/credentials-leak/"'';
              description = mdDoc "Path where global credentials leak check configuration files will be stored.";
            };
            trivy = mkOption {
              description = mdDoc "Configuration for detecting credentials leaks using Trivy.";
              default = { };
              type = types.submodule {
                options = {
                  enabled = mkEnableOption (mdDoc "credentials leak detection with Trivy");
                };
              };
            };
          };
        };
        description = mdDoc "Options for credential leak detection in container images.";
      };
    };
  };
}

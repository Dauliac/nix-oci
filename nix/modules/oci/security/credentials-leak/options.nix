{
  config,
  lib,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkOption
    mkEnableOption
    types
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
              defaultText = lib.literalExpression ''config.oci.rootPath + "/credentials-leak/"'';
              description = "Path where global credentials leak check configuration files will be stored.";
            };
            trivy = mkOption {
              description = "Configuration for detecting credentials leaks using Trivy.";
              default = { };
              type = types.submodule {
                options = {
                  enabled = mkEnableOption "credentials leak detection with Trivy";
                };
              };
            };
          };
        };
        description = "Options for credential leak detection in container images.";
      };
    };
  };
}

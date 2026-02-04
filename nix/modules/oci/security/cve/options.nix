{
  config,
  lib,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkOption
    types
    mkEnableOption
    ;
in
{
  options = {
    oci = {
      cve = mkOption {
        default = { };
        description = "Configuration for Common Vulnerabilities and Exposures (CVE) scanning in container images.";
        type = types.submodule {
          options = {
            configPath = mkOption {
              type = types.path;
              default = cfg.oci.rootPath;
              defaultText = lib.literalExpression "cfg.oci.rootPath";
              description = "Path where CVE scanner configuration files will be stored.";
            };
            trivy = mkOption {
              description = "Configuration for CVE scanning using Trivy.";
              default = { };
              type = types.submodule {
                options = {
                  enabled = mkEnableOption "CVE scanning with Trivy";
                  ignore = mkOption {
                    default = { };
                    description = "Configuration for CVE exclusions in Trivy scans.";
                    type = types.submodule {
                      options = {
                        fileEnabled = mkEnableOption "Trivy CVE ignore file generation";
                        rootPath = mkOption {
                          type = types.path;
                          description = "Path where Trivy CVE ignore files will be stored.";
                          default = cfg.oci.cve.configPath;
                          defaultText = lib.literalExpression "cfg.oci.cve.configPath";
                        };
                        extra = mkOption {
                          type = types.listOf types.str;
                          description = "Additional CVE identifiers to ignore globally in Trivy scans.";
                          default = [ ];
                        };
                      };
                    };
                  };
                };
              };
            };
            grype = mkOption {
              description = "Configuration for CVE scanning using Grype.";
              default = { };
              type = types.submodule {
                options = {
                  enabled = mkEnableOption "CVE scanning with Grype";
                  config = mkOption {
                    default = { };
                    description = "Configuration for Grype scanner settings.";
                    type = types.submodule {
                      options = {
                        enabled = mkEnableOption "Grype configuration file generation";
                        rootPath = mkOption {
                          type = types.path;
                          description = "Path where Grype configuration files will be stored.";
                          default = cfg.oci.cve.configPath + "/grype/";
                          defaultText = lib.literalExpression ''config.oci.cve.configPath + "/grype/"'';
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
